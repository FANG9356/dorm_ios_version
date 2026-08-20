---
name: System Architecture and Constraints
description: Guidelines on server architecture, storage, and deployment environments.
---
# System Architecture and Constraints

## 1. Storage and Server Role
- **Local Storage First:** All heavy media files (images, profile pictures, documents, etc.) MUST be stored locally on the client device (e.g., iOS FileManager or CoreData).
- **Server as Intermediary:** The Go backend server is strictly a sync middleman. It is used to sync text data, statuses, and messages between devices.
- **No Heavy Server Storage:** The backend MUST NOT be designed to permanently host or store heavy media files. The server does not host static media for the clients. Syncing media between devices should be done using the server as a pass-through intermediary or via peer-to-peer/other local network methods, without persistent storage on the server.

## 2. Deployment Information
- **Server:** `202.29.232.28`
- **SSH User:** `fang`
- **SSH Password:** `2550`
- **Deployment Process:** When backend code is updated, it must be deployed to this server for changes to take effect in the production environment (`api.dorminet.studio`).
