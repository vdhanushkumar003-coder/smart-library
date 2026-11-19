CREATE DATABASE IF NOT EXISTS smart_library CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE smart_library;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('member', 'admin') NOT NULL DEFAULT 'member',
  phone VARCHAR(30),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_reset_expiry (expires_at)
);

CREATE TABLE IF NOT EXISTS categories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS books (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(240) NOT NULL,
  author VARCHAR(180) NOT NULL,
  isbn VARCHAR(24) NOT NULL UNIQUE,
  category_id BIGINT UNSIGNED,
  publisher VARCHAR(180),
  publication_year SMALLINT UNSIGNED,
  copies_total INT UNSIGNED NOT NULL DEFAULT 1,
  copies_available INT UNSIGNED NOT NULL DEFAULT 1,
  rack_code VARCHAR(32),
  shelf_code VARCHAR(32),
  cover_url VARCHAR(500),
  description TEXT,
  qr_code CHAR(36) NOT NULL UNIQUE,
  pdf_url VARCHAR(500),
  pdf_is_licensed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_books_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
  INDEX idx_books_title (title),
  INDEX idx_books_author (author),
  INDEX idx_books_category (category_id),
  INDEX idx_books_available (copies_available),
  INDEX idx_books_location (rack_code, shelf_code)
);

DELIMITER $$
DROP PROCEDURE IF EXISTS ensure_book_location_columns$$
CREATE PROCEDURE ensure_book_location_columns()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'books' AND COLUMN_NAME = 'rack_code'
  ) THEN
    ALTER TABLE books ADD COLUMN rack_code VARCHAR(32) NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'books' AND COLUMN_NAME = 'shelf_code'
  ) THEN
    ALTER TABLE books ADD COLUMN shelf_code VARCHAR(32) NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'books' AND INDEX_NAME = 'idx_books_location'
  ) THEN
    ALTER TABLE books ADD INDEX idx_books_location (rack_code, shelf_code);
  END IF;
END$$
CALL ensure_book_location_columns()$$
DROP PROCEDURE ensure_book_location_columns$$
DELIMITER ;

CREATE TABLE IF NOT EXISTS book_issues (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  book_id BIGINT UNSIGNED NOT NULL,
  issue_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_date DATETIME NOT NULL,
  status ENUM('issued', 'returned') NOT NULL DEFAULT 'issued',
  issued_by BIGINT UNSIGNED,
  returned_at DATETIME,
  CONSTRAINT fk_issues_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_issues_book FOREIGN KEY (book_id) REFERENCES books(id),
  CONSTRAINT fk_issues_issuer FOREIGN KEY (issued_by) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_issues_user_status (user_id, status),
  INDEX idx_issues_due_status (due_date, status)
);

CREATE TABLE IF NOT EXISTS book_returns (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  issue_id BIGINT UNSIGNED NOT NULL UNIQUE,
  returned_by BIGINT UNSIGNED NOT NULL,
  returned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  overdue_days INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_returns_issue FOREIGN KEY (issue_id) REFERENCES book_issues(id),
  CONSTRAINT fk_returns_user FOREIGN KEY (returned_by) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS transactions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  book_id BIGINT UNSIGNED NOT NULL,
  issue_id BIGINT UNSIGNED,
  type ENUM('issue', 'return') NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_transactions_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_transactions_book FOREIGN KEY (book_id) REFERENCES books(id),
  CONSTRAINT fk_transactions_issue FOREIGN KEY (issue_id) REFERENCES book_issues(id) ON DELETE SET NULL,
  INDEX idx_transactions_created (created_at)
);

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  message VARCHAR(500) NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notifications_user (user_id, is_read)
);

CREATE TABLE IF NOT EXISTS loan_reminders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  issue_id BIGINT UNSIGNED NOT NULL,
  reminder_key VARCHAR(32) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_loan_reminder_issue FOREIGN KEY (issue_id) REFERENCES book_issues(id) ON DELETE CASCADE,
  UNIQUE KEY uq_loan_reminder_issue_key (issue_id, reminder_key)
);

CREATE TABLE IF NOT EXISTS reading_history (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  book_id BIGINT UNSIGNED NOT NULL,
  last_read_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_history_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_history_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  UNIQUE KEY uq_history_user_book (user_id, book_id)
);

CREATE TABLE IF NOT EXISTS book_reviews (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  book_id BIGINT UNSIGNED NOT NULL,
  rating TINYINT UNSIGNED NOT NULL,
  review TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_reviews_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5),
  UNIQUE KEY uq_review_user_book (user_id, book_id)
);

CREATE TABLE IF NOT EXISTS book_chapters (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  book_id BIGINT UNSIGNED NOT NULL,
  chapter_number INT UNSIGNED NOT NULL,
  title VARCHAR(240) NOT NULL,
  content LONGTEXT NOT NULL,
  rights_basis VARCHAR(500) NOT NULL,
  rights_verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_by BIGINT UNSIGNED,
  verified_at DATETIME,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_chapters_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  CONSTRAINT fk_chapters_verifier FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_chapter_book_number (book_id, chapter_number),
  INDEX idx_chapter_rights (book_id, rights_verified)
);

CREATE TABLE IF NOT EXISTS ebook_sources (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL UNIQUE,
  homepage_url VARCHAR(1000),
  terms_note VARCHAR(500) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ebooks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  book_id BIGINT UNSIGNED NOT NULL,
  source_id BIGINT UNSIGNED NOT NULL,
  language_code VARCHAR(12) NOT NULL DEFAULT 'en',
  rights_basis VARCHAR(500) NOT NULL,
  rights_verified BOOLEAN NOT NULL DEFAULT FALSE,
  verified_by BIGINT UNSIGNED,
  verified_at DATETIME,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ebooks_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
  CONSTRAINT fk_ebooks_source FOREIGN KEY (source_id) REFERENCES ebook_sources(id),
  CONSTRAINT fk_ebooks_verifier FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL,
  UNIQUE KEY uq_ebook_book_source (book_id, source_id),
  INDEX idx_ebook_rights (rights_verified, book_id)
);

CREATE TABLE IF NOT EXISTS ebook_files (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ebook_id BIGINT UNSIGNED NOT NULL,
  file_format ENUM('chapters', 'pdf', 'epub', 'html', 'txt', 'external') NOT NULL,
  file_url VARCHAR(1000),
  total_pages INT UNSIGNED,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ebook_files_ebook FOREIGN KEY (ebook_id) REFERENCES ebooks(id) ON DELETE CASCADE,
  UNIQUE KEY uq_ebook_file_format (ebook_id, file_format)
);

CREATE TABLE IF NOT EXISTS reading_progress (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  ebook_id BIGINT UNSIGNED NOT NULL,
  chapter_number INT UNSIGNED NOT NULL DEFAULT 1,
  last_page INT UNSIGNED NOT NULL DEFAULT 1,
  total_pages INT UNSIGNED NOT NULL DEFAULT 1,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_reading_progress_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_reading_progress_ebook FOREIGN KEY (ebook_id) REFERENCES ebooks(id) ON DELETE CASCADE,
  UNIQUE KEY uq_reading_progress_user_ebook (user_id, ebook_id)
);

CREATE TABLE IF NOT EXISTS bookmarks (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  ebook_id BIGINT UNSIGNED NOT NULL,
  chapter_number INT UNSIGNED NOT NULL DEFAULT 1,
  page_number INT UNSIGNED NOT NULL,
  note VARCHAR(500),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_bookmarks_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_bookmarks_ebook FOREIGN KEY (ebook_id) REFERENCES ebooks(id) ON DELETE CASCADE,
  UNIQUE KEY uq_bookmark_user_location (user_id, ebook_id, chapter_number, page_number),
  INDEX idx_bookmarks_user_ebook (user_id, ebook_id)
);

INSERT IGNORE INTO ebook_sources (name, homepage_url, terms_note) VALUES
  ('Smart Library', NULL, 'Content supplied by the library; staff must verify its distribution rights before publication.'),
  ('Project Gutenberg', 'https://www.gutenberg.org/', 'Public-domain status varies by jurisdiction. Follow the source edition’s terms and verify local rights before use.'),
  ('Project Madurai', 'https://www.projectmadurai.org/', 'Check the individual work’s copyright notice and terms; catalog availability alone is not a license.');

CREATE TABLE IF NOT EXISTS seating_zones (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  description VARCHAR(255),
  total_seats INT UNSIGNED NOT NULL DEFAULT 0,
  features VARCHAR(255),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS seat_reservations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  zone_id BIGINT UNSIGNED NOT NULL,
  reservation_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status ENUM('reserved','cancelled','completed') NOT NULL DEFAULT 'reserved',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_seat_reservation_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_seat_reservation_zone FOREIGN KEY (zone_id) REFERENCES seating_zones(id) ON DELETE CASCADE,
  INDEX idx_seat_reservation_lookup (zone_id, reservation_date, status),
  INDEX idx_seat_reservation_user (user_id, reservation_date, status)
);

INSERT IGNORE INTO seating_zones (name, description, total_seats, features) VALUES
  ('The Reading Window', 'Bright tables beside the library windows', 24, 'Natural light · Power outlets'),
  ('Quiet Study', 'Individual desks for focused reading and study', 18, 'Silent zone · Desk lamps'),
  ('The Commons', 'Comfortable tables for group work and conversation', 30, 'Group tables · Wi-Fi'),
  ('Garden Corner', 'Calm lounge seating near the garden', 12, 'Soft seating · Accessible');

INSERT IGNORE INTO categories (name, description) VALUES
  ('Fiction', 'Novels, short stories and imaginative writing'),
  ('Science', 'Discoveries, nature and the world around us'),
  ('Technology', 'Computing, engineering and innovation'),
  ('History', 'People, places and events through time'),
  ('Personal growth', 'Practical ideas for learning and wellbeing'),
  ('Children', 'Stories and learning for younger readers');

INSERT IGNORE INTO books
  (title, author, isbn, category_id, publisher, publication_year, copies_total, copies_available, cover_url, description, qr_code)
VALUES
  ('The Midnight Library', 'Matt Haig', '9780525559474', 1, 'Viking', 2020, 5, 5, 'https://covers.openlibrary.org/b/isbn/9780525559474-L.jpg', 'Between life and death there is a library, and within that library, the shelves go on forever.', UUID()),
  ('A Brief History of Time', 'Stephen Hawking', '9780553380163', 2, 'Bantam', 1998, 4, 4, 'https://covers.openlibrary.org/b/isbn/9780553380163-L.jpg', 'A landmark exploration of the universe and our place within it.', UUID()),
  ('Atomic Habits', 'James Clear', '9780735211292', 5, 'Avery', 2018, 6, 6, 'https://covers.openlibrary.org/b/isbn/9780735211292-L.jpg', 'An approachable guide to building good habits and breaking bad ones.', UUID()),
  ('The Design of Everyday Things', 'Don Norman', '9780465050659', 3, 'Basic Books', 2013, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780465050659-L.jpg', 'A classic introduction to the principles of human-centered design.', UUID()),
  ('Pride and Prejudice', 'Jane Austen', '9780141439518', 1, 'Penguin Classics', 2002, 4, 4, 'https://covers.openlibrary.org/b/isbn/9780141439518-L.jpg', 'A beloved novel of manners, first impressions and enduring affection.', UUID()),
  ('The Boy, the Mole, the Fox and the Horse', 'Charlie Mackesy', '9780062976581', 6, 'HarperOne', 2019, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780062976581-L.jpg', 'A gentle illustrated story about kindness, courage and friendship.', UUID()),
  ('1984', 'George Orwell', '9780451524935', (SELECT id FROM categories WHERE name = 'Fiction'), 'Signet Classics', 1950, 4, 4, 'https://covers.openlibrary.org/b/isbn/9780451524935-L.jpg', 'A landmark dystopian novel about truth, power and individual freedom.', UUID()),
  ('The Hobbit', 'J.R.R. Tolkien', '9780547928227', (SELECT id FROM categories WHERE name = 'Fiction'), 'Mariner Books', 2012, 4, 4, 'https://covers.openlibrary.org/b/isbn/9780547928227-L.jpg', 'A home-loving hobbit sets out on an unexpected adventure across Middle-earth.', UUID()),
  ('The Catcher in the Rye', 'J.D. Salinger', '9780316769488', (SELECT id FROM categories WHERE name = 'Fiction'), 'Little, Brown and Company', 1991, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780316769488-L.jpg', 'A candid coming-of-age novel told over a few eventful days in New York.', UUID()),
  ('To Kill a Mockingbird', 'Harper Lee', '9780061120084', (SELECT id FROM categories WHERE name = 'Fiction'), 'Harper Perennial', 2006, 4, 4, 'https://covers.openlibrary.org/b/isbn/9780061120084-L.jpg', 'A young narrator observes courage, justice and community in the American South.', UUID()),
  ('The Alchemist', 'Paulo Coelho', '9780061122415', (SELECT id FROM categories WHERE name = 'Fiction'), 'HarperOne', 2014, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780061122415-L.jpg', 'A shepherd follows a journey of discovery in this modern fable.', UUID()),
  ('The Silent Patient', 'Alex Michaelides', '9781250301697', (SELECT id FROM categories WHERE name = 'Fiction'), 'Celadon Books', 2019, 3, 3, 'https://covers.openlibrary.org/b/isbn/9781250301697-L.jpg', 'A psychological mystery follows a therapist investigating a celebrated artist.', UUID()),
  ('Sapiens: A Brief History of Humankind', 'Yuval Noah Harari', '9780062316097', (SELECT id FROM categories WHERE name = 'History'), 'Harper', 2015, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780062316097-L.jpg', 'An accessible exploration of the forces that shaped human societies.', UUID()),
  ('The Diary of a Young Girl', 'Anne Frank', '9780553296983', (SELECT id FROM categories WHERE name = 'History'), 'Bantam', 1993, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780553296983-L.jpg', 'A young diarist records daily life, hope and resilience during wartime.', UUID()),
  ('Cosmos', 'Carl Sagan', '9780345539434', (SELECT id FROM categories WHERE name = 'Science'), 'Ballantine Books', 2013, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780345539434-L.jpg', 'A celebrated introduction to the universe and the scientific ideas that help us understand it.', UUID()),
  ('The Body: A Guide for Occupants', 'Bill Bryson', '9780385539302', (SELECT id FROM categories WHERE name = 'Science'), 'Doubleday', 2019, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780385539302-L.jpg', 'A lively tour of the human body and the science behind everyday life.', UUID()),
  ('The Pragmatic Programmer', 'David Thomas and Andrew Hunt', '9780135957059', (SELECT id FROM categories WHERE name = 'Technology'), 'Addison-Wesley Professional', 2019, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780135957059-L.jpg', 'Practical ideas and habits for building better software and becoming a more effective developer.', UUID()),
  ('Clean Code', 'Robert C. Martin', '9780132350884', (SELECT id FROM categories WHERE name = 'Technology'), 'Prentice Hall', 2008, 2, 2, 'https://covers.openlibrary.org/b/isbn/9780132350884-L.jpg', 'A software craftsmanship guide focused on writing clear, maintainable code.', UUID()),
  ('Deep Work', 'Cal Newport', '9781455586691', (SELECT id FROM categories WHERE name = 'Personal growth'), 'Grand Central Publishing', 2016, 3, 3, 'https://covers.openlibrary.org/b/isbn/9781455586691-L.jpg', 'A practical case for focused work and making room for meaningful concentration.', UUID()),
  ('Thinking, Fast and Slow', 'Daniel Kahneman', '9780374533557', (SELECT id FROM categories WHERE name = 'Personal growth'), 'Farrar, Straus and Giroux', 2013, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780374533557-L.jpg', 'A Nobel laureate explains two modes of thought and how they shape our decisions.', UUID()),
  ('Educated', 'Tara Westover', '9780399590504', (SELECT id FROM categories WHERE name = 'Personal growth'), 'Random House', 2018, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780399590504-L.jpg', 'A memoir about education, family and forging an independent path.', UUID()),
  ('Charlotte''s Web', 'E.B. White', '9780064400558', (SELECT id FROM categories WHERE name = 'Children'), 'HarperCollins', 1980, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780064400558-L.jpg', 'A much-loved farmyard story about friendship, kindness and a remarkable spider.', UUID()),
  ('Wonder', 'R.J. Palacio', '9780375869020', (SELECT id FROM categories WHERE name = 'Children'), 'Knopf Books for Young Readers', 2012, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780375869020-L.jpg', 'A boy starting school discovers how small acts of kindness can change a community.', UUID()),
  ('The Very Hungry Caterpillar', 'Eric Carle', '9780399226908', (SELECT id FROM categories WHERE name = 'Children'), 'World of Eric Carle', 1994, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780399226908-L.jpg', 'A colorful picture-book classic that introduces counting, food and transformation.', UUID()),
  ('Little Women', 'Louisa May Alcott', '9780147514011', (SELECT id FROM categories WHERE name = 'Fiction'), 'Puffin Classics', 2014, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780147514011-L.jpg', 'The four March sisters grow up, pursue their dreams and find their way through change.', UUID()),
  ('Ikigai: The Japanese Secret to a Long and Happy Life', 'Héctor García and Francesc Miralles', '9780143130727', (SELECT id FROM categories WHERE name = 'Personal growth'), 'Penguin Life', 2017, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780143130727-L.jpg', 'An inviting look at purpose, daily rituals and the small things that bring meaning.', UUID()),
  ('The Book Thief', 'Markus Zusak', '9780375842207', (SELECT id FROM categories WHERE name = 'Fiction'), 'Knopf Books for Young Readers', 2007, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780375842207-L.jpg', 'A young girl finds comfort in books and friendship in a story set during wartime Germany.', UUID()),
  ('Where the Crawdads Sing', 'Delia Owens', '9780735219090', (SELECT id FROM categories WHERE name = 'Fiction'), 'G.P. Putnam''s Sons', 2018, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780735219090-L.jpg', 'A coming-of-age story and mystery set in the coastal marshes of North Carolina.', UUID()),
  ('The Great Gatsby', 'F. Scott Fitzgerald', '9780743273565', (SELECT id FROM categories WHERE name = 'Fiction'), 'Scribner', 2004, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780743273565-L.jpg', 'A portrait of ambition, longing and the glittering Jazz Age on Long Island.', UUID()),
  ('Brave New World', 'Aldous Huxley', '9780060850524', (SELECT id FROM categories WHERE name = 'Fiction'), 'Harper Perennial Modern Classics', 2006, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780060850524-L.jpg', 'A classic speculative novel about technology, social order and individual choice.', UUID()),
  ('The Little Prince', 'Antoine de Saint-Exupéry', '9780156012195', (SELECT id FROM categories WHERE name = 'Children'), 'Mariner Books', 2000, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780156012195-L.jpg', 'A pilot meets a curious young visitor in this illustrated tale about friendship and seeing what matters.', UUID()),
  ('Harry Potter and the Sorcerer''s Stone', 'J.K. Rowling', '9780590353427', (SELECT id FROM categories WHERE name = 'Children'), 'Scholastic', 1999, 4, 4, 'https://covers.openlibrary.org/b/isbn/9780590353427-L.jpg', 'An invitation to a school of magic begins a young wizard''s first adventure.', UUID()),
  ('The Lightning Thief', 'Rick Riordan', '9780786838653', (SELECT id FROM categories WHERE name = 'Children'), 'Disney-Hyperion', 2005, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780786838653-L.jpg', 'A modern-day boy discovers a surprising connection to the world of Greek mythology.', UUID()),
  ('Matilda', 'Roald Dahl', '9780142410370', (SELECT id FROM categories WHERE name = 'Children'), 'Puffin Books', 2007, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780142410370-L.jpg', 'A clever young reader discovers the power of confidence, kindness and a little magic.', UUID()),
  ('The Giving Tree', 'Shel Silverstein', '9780060256654', (SELECT id FROM categories WHERE name = 'Children'), 'Harper & Row', 1964, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780060256654-L.jpg', 'An illustrated story that invites readers to reflect on generosity and growing up.', UUID()),
  ('A Wrinkle in Time', 'Madeleine L''Engle', '9780312367541', (SELECT id FROM categories WHERE name = 'Children'), 'Square Fish', 2007, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780312367541-L.jpg', 'Three young travelers venture across space and time to bring someone they love home.', UUID()),
  ('The Immortal Life of Henrietta Lacks', 'Rebecca Skloot', '9781400052189', (SELECT id FROM categories WHERE name = 'Science'), 'Crown', 2010, 2, 2, 'https://covers.openlibrary.org/b/isbn/9781400052189-L.jpg', 'A deeply reported account of a family, medical research and the legacy of a remarkable cell line.', UUID()),
  ('Factfulness', 'Hans Rosling, Ola Rosling and Anna Rosling Rönnlund', '9781250107817', (SELECT id FROM categories WHERE name = 'Science'), 'Flatiron Books', 2018, 3, 3, 'https://covers.openlibrary.org/b/isbn/9781250107817-L.jpg', 'A data-informed guide to seeing global trends more clearly and questioning common assumptions.', UUID()),
  ('Man''s Search for Meaning', 'Viktor E. Frankl', '9780807014295', (SELECT id FROM categories WHERE name = 'Personal growth'), 'Beacon Press', 2006, 3, 3, 'https://covers.openlibrary.org/b/isbn/9780807014295-L.jpg', 'A psychiatrist reflects on resilience, purpose and the search for meaning in difficult times.', UUID()),
  ('Guns, Germs, and Steel', 'Jared Diamond', '9780393354324', (SELECT id FROM categories WHERE name = 'History'), 'W. W. Norton & Company', 2017, 2, 2, 'https://covers.openlibrary.org/b/isbn/9780393354324-L.jpg', 'A broad exploration of geography, agriculture and the forces that shaped human societies.', UUID());

UPDATE books
SET rack_code = CONCAT('R', MOD(id - 1, 8) + 1),
    shelf_code = CONCAT('S', MOD(FLOOR((id - 1) / 8), 5) + 1)
WHERE rack_code IS NULL AND shelf_code IS NULL;

INSERT IGNORE INTO ebooks (book_id, source_id, language_code, rights_basis, rights_verified, verified_at)
SELECT b.id, s.id, 'en',
  'Project Gutenberg edition of the public-domain original; public-domain status is jurisdiction-dependent.',
  TRUE, CURRENT_TIMESTAMP
FROM books b
JOIN ebook_sources s ON s.name = 'Project Gutenberg'
WHERE b.isbn IN ('9780141439518', '9780147514011');

INSERT IGNORE INTO ebook_files (ebook_id, file_format, file_url)
SELECT e.id, 'external',
  CASE b.isbn
    WHEN '9780141439518' THEN 'https://www.gutenberg.org/ebooks/1342'
    WHEN '9780147514011' THEN 'https://www.gutenberg.org/ebooks/514'
  END
FROM ebooks e
JOIN books b ON b.id = e.book_id
JOIN ebook_sources s ON s.id = e.source_id
WHERE s.name = 'Project Gutenberg'
  AND b.isbn IN ('9780141439518', '9780147514011');
