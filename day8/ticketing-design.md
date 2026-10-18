# TicketHub System Design Document

## 1. Requirements

### Functional Requirements

- **User Management:** Users can register, log in, and view their profile.
- **Event Discovery:** Users can browse and search upcoming concerts and events.
- **Seat Map & Selection:** Users can view a real-time seat availability map for an event.
- **Seat Holding (Temporary Lock):** Users can select and temporarily hold specific seats for a limited window (e.g., 10 minutes) while completing payment.
- **Checkout & Payment:** Users can securely submit payment information to finalize ticket purchases.
- **Order History:** Users can view their purchased tickets and active orders.

### Non-Functional Requirements

- **Speed:** Sub-200ms API response latency for event browsing and seat map loading under normal traffic.
- **Correctness:** Absolute data integrity—under no circumstances can two users successfully book the same seat (zero double-bookings).
- **Fairness:** During flash sales, a First-In, First-Out (FIFO) queuing mechanism ensures fair access, preventing automated bots from instantly buying out inventory.
- **High Availability:** The system must remain stable and responsive during massive traffic spikes (flash sales).

---

## 2. Traffic Estimates

### Baseline (Normal Day)

- **Registered Users:** 2,000,000 users.
- **Daily Active Visitors:** 50,000 visitors.
- **Page Views:** 50,000 visitors $\times$ 10 pages/day = **500,000 page views/day** ($\approx$ 5.8 requests/sec average).
- **Tickets Sold:** **5,000 tickets sold/day**.

### Flash Sale Peak ("Popular Concert On-Sale")

- **Traffic Spike:** **200,000 concurrent users** attempting to purchase **20,000 seats** within the first **10 minutes** (600 seconds).
- **Peak Write / Selection Load:** Up to tens of thousands of requests per second hitting the seat-holding and checkout services concurrently, representing a $100\times$ increase over normal operation.

---

## 3. REST API Design

| Method | Endpoint                    | Description                                   | Success Status |
| :----- | :-------------------------- | :-------------------------------------------- | :------------- |
| `GET`  | `/api/v1/events`            | Browse or search upcoming events              | `200 OK`       |
| `GET`  | `/api/v1/events/{id}/seats` | Retrieve real-time seat availability map      | `200 OK`       |
| `POST` | `/api/v1/seats/hold`        | Temporarily hold selected seats (10-min TTL)  | `201 Created`  |
| `POST` | `/api/v1/checkout`          | Process payment and confirm ticket purchase   | `200 OK`       |
| `GET`  | `/api/v1/users/{id}/orders` | Retrieve order history and tickets for a user | `200 OK`       |

**Example Request (`POST /api/v1/seats/hold`):**

```json
{
  "user_id": 42,
  "event_id": 101,
  "seat_ids": ["A12", "A13"]
}
```

4. Data Model (Relational Schema)
   users: Stores user profile information.

id: INTEGER (Primary Key)

name: TEXT (NOT NULL)

email: TEXT (UNIQUE, NOT NULL)

events: Stores concert and event details.

id: INTEGER (Primary Key)

title: TEXT (NOT NULL)

event_date: DATETIME (NOT NULL)

total_seats: INTEGER (NOT NULL)

seats: Stores individual seat inventory status.

id: INTEGER (Primary Key)

event_id: INTEGER (Foreign Key referencing events(id))

seat_number: TEXT (NOT NULL)

status: TEXT (ENUM: available, held, booked)

held_until: DATETIME (Timestamp for expiration of temporary hold)

orders: Stores completed transactions and ticket ownership.

id: INTEGER (Primary Key)

user_id: INTEGER (Foreign Key referencing users(id))

seat_id: INTEGER (Foreign Key referencing seats(id), UNIQUE)

amount: DECIMAL (NOT NULL)

created_at: DATETIME (DEFAULT CURRENT_TIMESTAMP)

5. Preventing Double-Booking (Concurrency Control)
   To guarantee that two users can never buy the same seat, TicketHub uses a multi-layered concurrency control strategy:

Redis Distributed Locks / TTL Keys: When a user clicks "Hold Seat", an atomic Redis operation checks if the seat key exists. If available, Redis sets a lock with a strict 10-minute TTL (Time-To-Live). This offloads heavy locking from the primary database during flash sales.

Database Transactions & Row-Level Locking (SELECT ... FOR UPDATE): When committing the payment in POST /api/v1/checkout, the application opens an ACID-compliant database transaction, locks the specific seat row using SELECT ... FOR UPDATE, verifies that the status is still held or available, updates the status to booked, and inserts the order record.

Unique Constraints: The orders table has a UNIQUE constraint on seat_id, ensuring that even if a race condition bypasses application logic, the database engine will reject duplicate inserts with a constraint violation error.

Architecture & Flash Sale Scaling Strategy
[ Users / Browsers ]
│
▼
[ Cloudflare DNS ]
│
▼
[ Cloudflare CDN ] (Static assets & cached event pages)
│
▼
[ Nginx Rate-Limiter / Load Balancer ]
│
▼
[ Virtual Waiting Room Queue ] (FIFO queue during flash sales)
│
┌───────┴───────┐
▼ ▼
[ App Server 1 ] [ App Server 2 ] (Stateless compute)
│ │
├───────────────┼─────────────┐
▼ ▼ ▼
[ Redis Cluster ] [ Message ] [ Primary Write DB ]
(Fast Seat Holds) [ Queue ] │
▼
[ Read Replicas ] (Browse / Event queries)

How the Architecture Survives the Big Sale:
CDN & Read Replicas: Static assets and event details are cached at the CDN and served from read replicas, keeping browsing traffic away from the primary database.

Virtual Waiting Room: When 200,000 users flood in, they are intercepted by a queuing service (e.g., Redis sorted sets or RabbitMQ) that lets users through in controlled batches, protecting application servers from crashing.

Redis for Hot Inventory: Seat locks are processed instantly in memory via Redis clusters rather than disk-bound SQL updates during the initial rush.

Trade-offs
Virtual Waiting Room vs. Immediate Access:

Trade-off: Introducing a queue adds friction and wait time for users.

Justification: Without a queue, millions of simultaneous requests crash servers instantly (availability failure). Throttling traffic guarantees system stability and fairness.

Eventual Consistency for Seat Maps vs. Strict Real-time Accuracy:

Trade-off: Showing seat availability via cached replicas might lag by a fraction of a second.

Justification: Routing all map views directly to the primary database would cause bottlenecking. Using cached seat status for browsing combined with strict locking only at the moment of holding/booking balances high read scalability with absolute transactional correctness.

## 2. Traffic Estimates & Comparison

### Baseline (Normal Day)

- **Registered Users:** 2,000,000 users.
- **Daily Active Visitors:** 50,000 visitors.
- **Page Views:** 50,000 visitors $\times$ 10 pages/day = **500,000 page views/day** ($\approx$ 5.8 requests/sec average).
- **Tickets Sold:** **5,000 tickets sold/day**.
- **Traffic Pattern:** Steady, predictable, and evenly distributed across various events and hours.

### Flash Sale Peak ("Popular Concert On-Sale")

- **Traffic Spike:** **200,000 concurrent users** attempting to purchase **20,000 seats** within the first **10 minutes** (600 seconds).
- **Peak Load:** Tens of thousands of simultaneous requests hitting seat-holding and checkout services concurrently—representing a **$100\times$ surge** over baseline traffic.
- **Traffic Pattern:** Highly localized, volatile, and hyper-concentrated on a single event page and seat map.

### Comparison Analysis

- **Volume vs. Concentration:** Normal traffic is low-volume and well-distributed across time and database rows. In contrast, the flash sale peak condenses immense user volume into a tiny 10-minute window.
- **Read-Heavy vs. Write/Lock-Contention:** Normal operations are read-heavy (browsing event listings and static details). The flash sale is an extreme write-and-lock contention event where thousands of users fight for the exact same subset of seats, shifting the primary engineering challenge from read scaling (caches/replicas) to concurrency control and transactional locking (Redis TTLs and database row locks).

## 4. System Trade-Offs & Architectural Decisions

### Trade-Off 1: Virtual Waiting Room vs. Direct Queue Load (User Experience vs. System Protection)

- **The Choice:** Implement an active virtual waiting room (throttling entry into the checkout funnel) rather than allowing all 200,000 concurrent users to hammer the primary API and database simultaneously.
- **Trade-Off:** While the waiting room introduces artificial friction and potential drop-offs for eager users who dislike queuing, it fundamentally protects the underlying infrastructure from cascading failures, memory exhaustion, and connection pool saturation. Without it, connection thrashing would cause response times to spike into timeouts for everyone.

### Trade-Off 2: Read Replicas with Eventual Consistency vs. Immediate Primary Reads (Scalability vs. Data Freshness)

- **The Choice:** Route high-volume seat browsing and venue mapping traffic to read replicas, reserving direct primary database queries strictly for checkout transactions and row-locking.
- **Trade-Off:** Read replicas introduce a slight replication lag (typically milliseconds to seconds), meaning a user might occasionally view a seat as "available" on their screen that was just claimed moments prior. We accept this minimal freshness delay because forcing all read queries onto the primary database would bottleneck throughput and invalidate our concurrency safeguards.
