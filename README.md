# Smart Library

A responsive public-library catalogue and lending application built with React, Express, and MySQL. Members can create accounts, browse and search the collection, check out and return books, keep a reading history, receive notices, review titles, and get recommendations based on their reading history and community popularity. Staff can manage books and covers, issue and return copies, scan book QR codes, review overdue loans, and export transaction history.

## Requirements

- Node.js 20 or newer and npm
- MySQL 8.0 or newer
- A modern browser; camera scanning requires HTTPS or `localhost`
- Optional SMTP credentials to enable password reset email

## Local setup

1. Create the database and 40 sample titles, plus the digital-edition tables and two source-linked public-domain classics:

   ```powershell
   mysql -u root -p < database\schema.sql
   ```

   If the database already exists, run the same command again to add any missing sample titles, rack/shelf columns, reminder table, and e-book tables. The schema checks for existing location columns before adding them. The book ISBNs are unique, so existing catalogue records are left unchanged.

2. Configure the API environment:

   ```powershell
   Copy-Item .env.example .env
   ```

   Set `DB_USER`, `DB_PASSWORD`, `DB_NAME`, and a unique, random `JWT_SECRET` of at least 32 characters. Keep `.env` private; it is excluded from version control.

3. Install dependencies:

   ```powershell
   npm install
   npm install --prefix server
   npm install --prefix client
   ```

4. Start both applications from the project root:

   ```powershell
   npm run dev
   ```

   The React application runs at <http://localhost:5173> and the API runs at <http://localhost:5000>. Check the database/API connection at <http://localhost:5000/api/health>.

   To run either service separately, use `npm run dev --prefix server` or `npm run dev --prefix client`. Build the frontend with `npm run build`.

## Staff account

Register an account through the website, then grant staff access directly in the database:

```sql
USE smart_library;
UPDATE users SET role = 'admin' WHERE email = 'staff@example.com';
```

Sign out and sign back in to receive a token with the updated role. Do not expose a public admin-registration route.

## Optional email-based password recovery

Password reset is available when SMTP is configured in `.env`: `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASSWORD`, and `EMAIL_FROM`. Reset links are random, stored as SHA-256 hashes, and expire after one hour. If no email transport is configured, the recovery page clearly directs the member to contact the library desk.

## Using the application

- **Members:** Register or sign in, browse/filter the catalogue, check out available books for 14 days, return current loans, view notifications and reading history, submit reviews, and open recommendations. Recommendations use each member’s digital reading categories and aggregate reading popularity—not a static “AI” list.
- **Due-date reminders:** The API checks active loans at startup and hourly. Members receive idempotent in-app reminders three days before, one day before, and on the due date; overdue loans receive one reminder per day. The `loan_reminders` table prevents duplicate notices across repeated scheduler runs.
- **Voice and image catalogue search:** On the catalogue page, voice search uses the browser speech recognition API (English or Tamil, depending on the selected language) to locate a title and show its rack and shelf. Image search runs English/Tamil OCR in the browser; images are not uploaded or stored. Images are limited to 5 MB.
- **Staff:** Select **Admin** to review collection and loan metrics, manage catalogue entries and cover images, issue and return books, scan book QR codes, view members and export transaction history as CSV.
- **Digital reading:** A PDF is readable only when staff supply a URL and explicitly confirm that the library has distribution rights. The sample catalogue does not include full-text PDFs.
- **Digital e-books:** Open **Digital E-Books** from the navigation drawer to browse editions with verified rights. The seed includes source links for *Pride and Prejudice* and *Little Women* at Project Gutenberg; the source hosts those complete works, and copyright status must be checked for the reader’s jurisdiction. Project Madurai is listed as a Tamil-literature directory; check each work’s own copyright notice and terms before use. Source-hosted editions open at their provider and are not copied into Smart Library.
- **Page-flip reader:** For text that the library is authorized to host, staff can add rights-verified chapters under **Admin → Digital reading**. Members can open those chapters in the StPageFlip reader, turn pages by touch or mouse, change font size/zoom and light/sepia/dark themes, search the loaded text, bookmark pages, and resume their last saved chapter/page when signed in. Existing authorized PDFs continue to open in the browser’s PDF viewer. EPUB or other source-hosted files open at their source rather than being presented as locally readable when the format cannot be rendered by the library.
- **Digital reading data:** `ebooks` and `ebook_files` store edition/source metadata; `ebook_sources` records provider notes; `reading_progress` and `bookmarks` are private to each signed-in member. Progress updates also maintain the existing reading history. Re-run `database\schema.sql` after updating to create these tables and seed the source editions.
- **Lumi – AI Reading Companion:** Open **Lumi** from the navigation to chat about books, choose a mood, browse three catalogue-based suggestions, and request verified book facts. The optional OpenAI-compatible provider is enabled only when `OPENAI_API_KEY` is set in the server `.env`; configure `OPENAI_MODEL` and `OPENAI_BASE_URL` there as needed. The key is never sent to the browser. Without a configured provider—or when the provider is unavailable—Lumi labels its reply and uses transparent deterministic recommendations from the library catalogue (or sample collection when the database is offline).
- **Lumi read aloud:** Each recommendation has a chapter reader with play, pause/resume, stop, English voice selection, speed controls, and paragraph/word highlighting where the browser supports it. The reader retrieves only text staff have marked rights-verified. Sample books intentionally have no full-text chapters. Speech playback uses the browser’s SpeechSynthesis API and does not upload chapter content to the AI provider.
- **Staff digital reading:** In **Admin → Digital reading**, staff can add, replace, and remove chapters for catalogue books. Each chapter requires a rights basis and an explicit rights confirmation. Only verified text is exposed to the public reader; chapter access can be revoked by deleting it.
- **Seating reservations:** Open **Library Seat Availability** in the menu or visit `/seats` to view reading areas, choose a date and time, and reserve or cancel a seat. Signed-in members use the shared MySQL reservation table; preview mode saves reservations on the device only when MySQL is unavailable.
- **Chat privacy:** Lumi conversation history remains in the current page session only and is cleared when the chat is cleared or the page is closed. It is not stored in the database.
- **Sample books:** The database seed includes 40 example titles across fiction, science, technology, history, personal growth, and children’s books. Cover thumbnails load from Open Library when available.
- **Preview without MySQL:** The public home page, catalogue filters, and sample book-detail pages use a clearly labelled local preview collection of the same 40 example titles while the API/database is unavailable. Browsing and searching work in preview mode; sign-in, live stock, loans, reviews, and admin actions require MySQL and use the server-backed catalogue.
- **QR codes:** Each book receives an unguessable UUID when added. Staff can print its QR code from book management; the checkout scanner uses a camera to resolve that code back to the catalogue.
- **English and Tamil:** Use the language switch in the header to change the translated navigation, catalogue controls, account screens, dashboard labels, Lumi prompts, voice recognition language, and AI response language. Book titles and factual catalogue content remain in their original language.

## Configuration and security notes

- API and database credentials stay on the server. The browser only communicates with the API; configure `VITE_API_URL` at client build time if the API is hosted somewhere other than `http://localhost:5000/api`.
- JWTs are held in browser session storage and authorization is checked on protected routes. Passwords are hashed with bcrypt; request bodies are validated; database queries use prepared statements; auth requests are rate limited; Helmet supplies security headers; CORS is restricted to `CLIENT_ORIGIN`.
- Cover uploads accept JPEG, PNG, or WebP up to 4 MB and are stored under `server/uploads` by default.
- For deployment, use HTTPS, a strong unique JWT secret, restricted database permissions, a private uploads directory or object storage, and a production SMTP provider. Set `CLIENT_ORIGIN` to the exact deployed frontend origin.
- Password reset requires the `password_reset_tokens` table included in `database/schema.sql`. If a database was created using an earlier schema, apply that table definition before enabling email reset.
- Lumi chapter management requires the `book_chapters` table in `database/schema.sql`. If the database already exists, rerun the schema command above to create the new table before adding chapters.

## Project layout

```text
client/       React application, pages, reusable components, and styles
server/       Express API, authentication, middleware, and route handlers
database/     MySQL schema and sample catalogue
.env.example  Server configuration template
```
