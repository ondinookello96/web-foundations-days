# SnapShare System Scaling Plan

## 1. Assumptions & Daily Active Users (DAU)

- **Total Registered Users:** 10,000,000
- **Activity Rate:** 10% of registered users are active daily.
- **Daily Active Users (DAU):** 10,000,000 $\times$ 0.10 = **1,000,000 active users per day**.
- **User Behavior:** Each active user uploads 1 photo per day and views 50 feed pages per day.
- **File Sizes:** Average photo size is 2 MB; thumbnail size is 50 KB (Total = 2.05 MB per upload).

---

## 2. Traffic and Storage Estimates

- **Uploads Per Day:** 1,000,000 users $\times$ 1 photo = **1,000,000 photos/day**.
- **Uploads Per Second (Average):** 1,000,000 / 86,400 seconds $\approx$ **11.57 uploads/sec**.
- **Feed Views Per Day:** 1,000,000 users $\times$ 50 feed views = **50,000,000 views/day**.
- **Feed Views Per Second (Average):** 50,000,000 / 86,400 seconds $\approx$ **578.7 views/sec**.
- **Feed Views Per Second (Peak):** 578.7 $\times$ 5 (peak multiplier) $\approx$ **2,894 views/sec**.
- **Storage Per Year:**
  - Photos/year: 1,000,000 $\times$ 365 = 365,000,000 photos.
  - Data/year: 365,000,000 $\times$ 2.05 MB = 747,250,000 MB $\approx$ **747.25 TB per year**.

---

## 3. Read-Heavy vs. Write-Heavy Architecture

- **Classification:** The system is **heavily read-heavy**.
- **Design Implications:** With ~2,894 peak feed reads per second compared to only ~12 writes per second, the architecture must prioritize fast read scaling. We implement caching layers, read replicas for the database, and a Content Delivery Network (CDN) to serve static media without overloading the primary database or backend app servers.

---

## 4. Why Photos Do Not Go Into the Database

Relational or traditional databases are optimized for structured tabular data, fast indexing, and ACID transactions. Storing large binary files (BLOBs) like 2MB images inside a database causes massive performance bloat, slows down query execution, increases backup times, and drives up expensive database storage costs. Instead, photos are stored in **Object Storage** (like AWS S3), while the database only stores metadata (file path/URL, user ID, caption, and timestamps).

---

## 5. Architecture Diagram

```text
       [ Clients / Mobile Apps ]
                  │
                  ▼
         [ CDN (Cloudflare) ]
                  │
                  ▼
       [ Load Balancer (Nginx) ]
                  │
         ┌────────┴────────┐
         ▼                 ▼
  [ App Server 1 ]   [ App Server 2 ]
         │                 │
         ├─────────────────┼──────────────┐
         ▼                 ▼              ▼
   [ Distributed      [ Message       [ Primary Database ]
      Cache ]          Queue ]                │
                        │                     ▼
                        ▼             [ Read Replica ]
                 [ Worker Node ]
                        │
                        ▼
               [ Object Storage ]
             (S3 - Photos & Thumbs)

---

## 6. Component Descriptions (Problem Solved)

CDN: Caches static images and thumbnails at edge locations globally, reducing latency for users loading image feeds.

Load Balancer: Distributes incoming user traffic evenly across multiple application servers to prevent single-server bottlenecks.

App Servers: Stateless compute nodes that process business logic, handle API requests, and coordinate authentication.

Cache (Redis): Stores hot data like recent user feeds and session tokens in-memory to ensure sub-millisecond retrieval times.

Message Queue: Asynchronously decouples heavy background tasks (like image resizing) from the main API request cycle.

Worker Node: Consumes jobs from the queue to process images, generate compressed thumbnails, and save them to storage.

Primary Database: Handles strict transactional write operations (user accounts, new photo metadata, and follow graphs).

Read Replica: Offloads heavy read queries (such as fetching user feeds and profiles) away from the primary database.

Object Storage: Provides highly scalable, cost-effective storage specifically engineered for large binary files and media assets.

---

## 7. Step-by-Step Upload Flow

Initiate Upload: The client app sends a photo file and metadata (caption, user ID) to the Load Balancer.

Route Request: The Load Balancer forwards the request to an available App Server.

Save Binary Asset: The App Server uploads the raw 2MB photo file directly to Object Storage and receives a storage URL back.

Queue Processing: The App Server writes the photo metadata (URL, user ID, timestamp) to the Primary Database and pushes an asynchronous thumbnail generation job onto the Message Queue.

Background Worker: A Worker Node picks up the job from the queue, pulls the raw photo from Object Storage, generates a 50 KB thumbnail, and uploads the thumbnail back to Object Storage.

Completion: The client receives a success response, and the new photo becomes available to populate followers' feeds.

---

## 8. System Trade-offs

Trade-off 1: Eventually Consistent Feeds vs. Immediate Consistency

Decision: We choose eventual consistency for user feeds. When a user uploads a photo, it might take a fraction of a second for background workers and cache invalidation to propagate the new post to followers' feeds.

Why: This avoids locking the database and ensures high write availability and speed, trading absolute instant synchronization for massive scalability.

Trade-off 2: Duplicating Data via Read Replicas and Cache

Decision: We maintain cached feeds and database read replicas.

Why: While this increases storage footprint and introduces data synchronization complexity, it is necessary to handle the high read-to-write ratio without crashing the primary database.

```
