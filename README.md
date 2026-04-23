# ScoutifyApps Architecture

This document gives:
- A platform-level architecture view across all repositories
- A component-level architecture section for each major service

## Platform Architecture (High Level)

```mermaid
flowchart LR
    User["User Browser"] --> UI["Scoutify UI (React)"]
    UI --> Node["Scoutify Host (Node + Express + Vite)"]
    Node -->|"API proxy"| Edge["Edge Gateway (YARP)"]

    Edge --> Auth["Auth API"]
    Edge --> Features["Features API"]
    Edge --> Stocks["Stocks API"]

    Auth --> Jwt["JWT Tokens"]
    UI -->|"Bearer Token"| Edge

    Features --> F1["Watchlist"]
    Features --> F2["Screener"]
    Features --> F3["Smart Money"]
    Features --> F4["Market Data"]
    Features --> F5["AI Chat Cards"]

    Stocks -->|"enqueue request"| Queue[("RabbitMQ or Azure Service Bus")]
    Queue -->|"consume"| Worker["AI Analysis Worker"]
    Worker --> Cache[("Redis Cache")]
    Worker --> Secrets[("Vault Local or Azure Key Vault")]
    Worker --> Providers["Alpha Vantage + Finnhub + OpenAI"]
    Worker -->|"enqueue response"| Queue
    Stocks -->|"correlate by RequestId"| Edge
```

## Component Architecture

### 1) `scoutify` (UI + Node Host)

```mermaid
flowchart LR
    Browser["Browser"] --> React["React Client"]
    React --> APICalls["/api calls"]
    APICalls --> Express["Express Server"]
    Express -->|"if configured"| Dotnet["Dotnet Edge Gateway"]
    Express -->|"fallback local routes"| Legacy["Node routes"]
```

- React handles pages and user interactions.
- Express hosts the app and can proxy all API traffic to .NET edge.
- JWT token is sent by client with API requests.

### 2) `scoutify-edge-gateway` (YARP)

```mermaid
flowchart LR
    Client["Client or Node Host"] --> Yarp["YARP Reverse Proxy"]
    Yarp --> RouteAuth["Route /api/auth/* -> Auth API"]
    Yarp --> RouteFeatures["Route /api/watchlist,screener,smart-money,market-data,ai/* -> Features API"]
    Yarp --> RouteStocks["Route /api/stocks/* -> Stocks API"]
```

- Central entry point for all backend APIs.
- Keeps client routing simple and backend services decoupled.

### 3) `scoutify-auth-api`

```mermaid
flowchart LR
    Req["Login/Register/Google"] --> AuthCtrl["Auth Controller"]
    AuthCtrl --> Users["User Directory"]
    AuthCtrl --> Token["Token Issuer"]
    Token --> Jwt["Signed JWT"]
    Jwt --> Resp["Auth Response"]
```

- Handles local and Google auth.
- Issues JWT used by all protected APIs.

### 4) `scoutify-features-api`

```mermaid
flowchart LR
    Req["Feature Request"] --> Ctrls["Feature Controllers"]
    Ctrls --> Service["FeatureDataService"]
    Service --> Data["Current: in-memory data"]
    Data --> Resp["JSON Response"]
```

- Powers watchlist, screener, smart money, market data, and AI chat/cards.
- Uses async service layer; easy to replace data source with DB/external services.

### 5) `scoutify-core-api` (Stocks API)

```mermaid
flowchart LR
    Req["POST /api/stocks/insights"] --> Ctrl["Stocks Controller"]
    Ctrl --> QueueSvc["InsightQueueService"]
    QueueSvc -->|"publish request"| Bus[("RabbitMQ or Service Bus")]
    Bus -->|"response message"| QueueSvc
    QueueSvc -->|"Task completion by RequestId"| Ctrl
    Ctrl --> Resp["Insight Response"]
```

- Async request/response orchestration for heavy stock insight generation.
- Correlation ID (`RequestId`) matches response to original request.

### 6) `scoutify-ai-analysis-service` (Worker)

```mermaid
flowchart LR
    Bus[("RabbitMQ or Service Bus")] --> Worker["AnalysisWorker"]
    Worker --> Cache["Redis Cache"]
    Worker --> Secrets["Vault Local or Azure Key Vault"]
    Worker --> Market["Market Data APIs"]
    Worker --> LLM["OpenAI"]
    Worker --> Bus
```

- Consumes stock analysis jobs asynchronously.
- Applies caching and secret retrieval.
- Calls market data + LLM providers and publishes final response.

### 7) `scoutify-deployment` (Infra)

```mermaid
flowchart LR
    Local["Local Docker Compose"] --> Rabbit["RabbitMQ"]
    Local --> Redis["Redis"]
    Local --> Vault["Vault dev"]
    Local --> Services["Edge + APIs + Worker + UI Host"]

    Cloud["Azure"] --> ServiceBus["Azure Service Bus"]
    Cloud --> KeyVault["Azure Key Vault"]
    Cloud --> Runtime["Container Apps or AKS"]
```

- Local desktop stack mirrors production communication pattern.
- Azure replaces local infra with managed equivalents.

## End-to-End Data Flow (Feature + AI)

1. User logs in through `Auth API` and gets a JWT.
2. User hits feature endpoints via edge gateway; `Features API` responds directly.
3. For deep AI insights, `Stocks API` enqueues request to message bus.
4. Worker processes request using cache, secrets, and external providers.
5. Worker publishes correlated response; `Stocks API` returns final insight to UI.
