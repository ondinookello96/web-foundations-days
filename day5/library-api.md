# Library REST API Design

This document outlines the REST API design specifications for managing books within the library system.

## Base URL

`https://api.librarysystem.com/v1`

---

## Endpoints Overview

### 1. List All Books

- **Method:** `GET`
- **Path:** `/books`
- **Description:** Retrieves a complete list of all books in the library inventory.
- **Success Status Code:** `200 OK`

### 2. List Books by Author

- **Method:** `GET`
- **Path:** `/books?author=AuthorName`
- **Description:** Retrieves a filtered list of books written by a specific author using a query parameter.
- **Success Status Code:** `200 OK`

### 3. Get One Book

- **Method:** `GET`
- **Path:** `/books/{id}`
- **Description:** Retrieves the detailed record of a single book specified by its unique ID.
- **Success Status Code:** `200 OK`

### 4. Create a Book

- **Method:** `POST`
- **Path:** `/books`
- **Description:** Adds a new book record to the library database.
- **Example Request Body:**
  ```json
  {
    "title": "Eloquent JavaScript",
    "author": "Marijn Haverbeke",
    "publishedYear": 2018,
    "genre": "Programming"
  }
  Success Status Code: 201 Created
  ```

5.  Update a Book
    Method: PUT

Path: /books/{id}

Description: Fully updates or replaces existing details for a specific book ID.

Example Request Body:
{
"title": "Eloquent JavaScript (3rd Edition)",
"author": "Marijn Haverbeke",
"publishedYear": 2018,
"genre": "Web Development"
}
Success Status Code: 200 OK 6. Delete a Book
Method: DELETE

Path: /books/{id}

Description: Removes a specific book record from the system by its ID.

Success Status Code: 204 No Content

400 Bad Request
When it happens: Triggered when the server receives malformed JSON, missing mandatory fields (e.g., trying to create a book without a title), or invalid data types.

Example Scenario: A client sends a POST /books request with an empty JSON body {} or omits the author field.

404 Not Found
When it happens: Triggered when the requested resource endpoint references an ID or path that does not exist in the database.

Example Scenario: A client requests GET /books/8492 for a book ID that has not been created or has already been deleted.
