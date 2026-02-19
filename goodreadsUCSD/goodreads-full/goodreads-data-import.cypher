//NOTE: This script loads full data set (~2.3m books)
//Embedding model: mxbai-embed-large
//Total loaded data size:
//??? nodes
//??? relationships

CREATE CONSTRAINT book_id IF NOT EXISTS FOR (b:Book) REQUIRE b.id IS UNIQUE;
CREATE CONSTRAINT author_id IF NOT EXISTS FOR (a:Author) REQUIRE a.authorId IS UNIQUE;
CREATE CONSTRAINT review_id IF NOT EXISTS FOR (r:Review) REQUIRE r.id IS UNIQUE;
CREATE CONSTRAINT user_id IF NOT EXISTS FOR (u:User) REQUIRE u.userId IS UNIQUE;
CREATE CONSTRAINT work_id IF NOT EXISTS FOR (w:Work) REQUIRE w.workId IS UNIQUE;
CREATE CONSTRAINT series_id IF NOT EXISTS FOR (s:Series) REQUIRE s.seriesId IS UNIQUE;
CREATE CONSTRAINT genre IF NOT EXISTS FOR (g:Genre) REQUIRE g.name IS UNIQUE;

CREATE INDEX review_user IF NOT EXISTS FOR (r:Review) ON (r.userId);

CREATE VECTOR INDEX `book-descriptions` IF NOT EXISTS
FOR (b:Book) ON b.embedding
OPTIONS {indexConfig: {
 `vector.dimensions`: 768,
 `vector.similarity_function`: 'cosine'
}};
CREATE VECTOR INDEX `review-text` IF NOT EXISTS
FOR (r:Review) ON r.embedding
OPTIONS {indexConfig: {
 `vector.dimensions`: 768,
 `vector.similarity_function`: 'cosine'
}};

//Load books
CALL apoc.load.json("file:///goodreads_books.json.gz") YIELD value as book
CALL (book) {
    MERGE (b:Book {id: book.book_id})
    SET b += apoc.map.clean(book, ['authors','similar_books','popular_shelves','series'],[""])
} in transactions of 10000 rows;

//Clean up Book properties
MATCH (b:Book)
CALL (b) {
     SET b.ratings_count = toInteger(b.ratings_count),
     b.text_reviews_count = toInteger(b.text_reviews_count),
     b.num_pages = toInteger(b.num_pages),
     b.average_rating = toFloat(b.average_rating)
} in transactions of 10000 rows;

//Create Book text property
MATCH (b:Book)
    WHERE b.description IS NOT NULL
    AND b.text IS NULL
CALL (b) {
     SET b.text = b.description
     REMOVE b.description
} in transactions of 10000 rows;

//Import initial authors for books
CALL apoc.load.json("file:///goodreads_books.json.gz") YIELD value as book
CALL (book) {
    UNWIND book.authors as author
    MERGE (a:Author {authorId: author.author_id})
    WITH author, a
    MATCH (b:Book {id: book.book_id})
    MERGE (a)-[r:WROTE]->(b)
} in transactions of 10000 rows;

//Hydrate Author nodes
CALL apoc.load.json("file:///goodreads_book_authors.json.gz") YIELD value as author
CALL (author) {
    MATCH (a:Author {authorId: author.author_id})
     SET a += apoc.map.clean(author, ['author_id'],[""])
} in transactions of 10000 rows;

//Load similar books
CALL apoc.load.json("file:///goodreads_books.json.gz") YIELD value as book
CALL (book) {
    MATCH (b:Book {id: book.book_id})
    WITH book, b
    WHERE book.similar_books IS NOT NULL
    UNWIND book.similar_books as similarBookId
    MATCH (b2:Book {id: similarBookId})
    MERGE (b)-[r:SIMILAR_TO]->(b2)
} in transactions of 10000 rows;

//Import initial Series for books
CALL apoc.load.json("file:///goodreads_books.json.gz") YIELD value as book
CALL (book) {
    MATCH (b:Book {id: book.book_id})
    WITH book, b
    WHERE size(book.series) > 0
    UNWIND book.series as series_id
    MERGE (s:Series {seriesId: series_id})
    MERGE (b)-[r:PART_OF]->(s)
} in transactions of 10000 rows;

//Hydrate Series nodes
CALL apoc.load.json("file:///goodreads_book_series.json.gz") YIELD value as series
CALL (series) {
    MATCH (s:Series {seriesId: series.series_id})
     SET s += apoc.map.clean(series, ['series_id'],[""])
} in transactions of 10000 rows;

//Clean up Series properties
MATCH (s:Series)
CALL (s) {
     SET s.numbered = toBoolean(s.numbered),
     s.primary_work_count = toInteger(s.primary_work_count),
     s.series_works_count = toInteger(s.series_works_count)
} in transactions of 10000 rows;

//Import initial Work for books
CALL apoc.load.json("file:///goodreads_books.json.gz") YIELD value as book
CALL (book) {
    MATCH (b:Book {id: book.book_id})
    WITH b, book
    WHERE book.work_id IS NOT NULL
    MERGE (w:Work {workId: book.work_id})
    MERGE (b)-[r:HAS_SOURCE]->(w)
} in transactions of 10000 rows;

//Hydrate Work nodes
CALL apoc.load.json("file:///goodreads_book_works.json.gz") YIELD value as work
CALL (work) {
    MATCH (w:Work {workId: work.work_id})
     SET w += apoc.map.clean(work, ['work_id'],[""])
} IN TRANSACTIONS OF 1000 ROWS;

//Clean up Work properties
MATCH (w:Work)
CALL (w) {
     SET w.books_count = toInteger(w.books_count),
     w.ratings_count = toInteger(w.ratings_count),
     w.ratings_sum = toInteger(w.ratings_sum),
     w.reviews_count = toInteger(w.reviews_count),
     w.text_reviews_count = toInteger(w.text_reviews_count)
} in transactions of 10000 rows;

//Add best edition of Work
MATCH (w:Work)
WHERE w.best_book_id IS NOT NULL
CALL (w) {
     MATCH (b:Book {id: w.best_book_id})
     MERGE (w)-[r:RECOMMENDED_EDITION]->(b)
     REMOVE w.best_book_id
} in transactions of 10000 rows;

//Import initial fuzzy Genres for books
CALL apoc.load.json("file:///goodreads_book_genres_initial.json.gz") YIELD value as bookGenres
CALL (bookGenres) {
  MATCH (b:Book {id: bookGenres.book_id})
  WITH b, bookGenres, bookGenres.genres as genreList, keys(bookGenres.genres) as genres
  UNWIND genres as genre
  MERGE (g:Genre {name: genre})
  MERGE (b)-[r:CATEGORIZED_BY]->(g)
    SET r.weight = genreList[genre]
} in transactions of 10000 rows;

//Import User-Book interactions (shelves)
CALL apoc.load.json("file:///goodreads_interactions_dedup.json.gz") YIELD value as interaction
CALL (interaction) {
  MATCH (b:Book {id: interaction.book_id})
  MERGE (u:User {userId: interaction.user_id})
  WITH b, u,
  CASE interaction.is_read
    WHEN false THEN "SHELVED"
    WHEN true THEN "READ"
    ELSE "HAS_INTERACTION"
  END AS relName
  MERGE (b)<-[r:$(relName)]-(u)
    SET r.date_added = datetime(apoc.date.convertFormat(interaction.date_added, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time')), r.date_updated = datetime(apoc.date.convertFormat(interaction.date_updated, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 10000 rows;

//Load Reviews
CALL apoc.load.json("file:///goodreads_reviews_dedup.json.gz") YIELD value as review
CALL (review) {
    MATCH (b:Book) WHERE b.id = review.book_id
    WITH review, b
    MERGE (r:Review {id: review.review_id})
     SET r += apoc.map.clean(review, ['review_id'],[""])
    WITH b, r
    MERGE (b)<-[rel:WRITTEN_FOR]-(r)
} in transactions of 10000 rows;

//Create Review text property
MATCH (r:Review)
    WHERE r.review_text IS NOT NULL
    AND r.text IS NULL
CALL (r) {
     SET r.text = r.review_text
     REMOVE r.review_text
} in transactions of 10000 rows;

//Clean up Review date_added property
MATCH (r:Review)
    WHERE r.date_added IS NOT NULL
    AND apoc.meta.cypher.type(r.date_added) = "STRING"
CALL (r) {
     SET r.date_added = datetime(apoc.date.convertFormat(r.date_added, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Clean up Review date_updated property
MATCH (r:Review)
    WHERE r.date_updated IS NOT NULL
    AND apoc.meta.cypher.type(r.date_updated) = "STRING"
CALL (r) {
     SET r.date_updated = datetime(apoc.date.convertFormat(r.date_updated, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Clean up Review started_at property
MATCH (r:Review)
WHERE r.started_at IS NOT NULL
    AND apoc.meta.cypher.type(r.started_at) = "STRING"
CALL (r) {
     SET r.started_at = datetime(apoc.date.convertFormat(r.started_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Remove Review read_at problem properties (invalid year)
MATCH (r:Review)
WHERE r.read_at IS NOT NULL
AND apoc.meta.cypher.type(r.read_at) = "STRING"
AND r.read_at ENDS WITH "0000"
 REMOVE r.read_at
RETURN count(r);

//Clean up Review read_at property
MATCH (r:Review)
WHERE r.read_at IS NOT NULL
AND apoc.meta.cypher.type(r.read_at) = "STRING"
CALL (r) {
     SET r.read_at = datetime(apoc.date.convertFormat(r.read_at, 'EEE LLL dd HH:mm:ss Z yyyy', 'iso_offset_date_time'))
} in transactions of 1000 rows;

//Separate User nodes from Review nodes
MATCH (r:Review)
WHERE r.user_id IS NOT NULL
CALL (r) {
    MERGE (u:User {userId: r.user_id})
    WITH r, u
    MERGE (r)<-[:PUBLISHED]-(u)
    REMOVE r.user_id
} in transactions of 1000 rows;

// //Book text chunking
// MATCH (b:Book WHERE b.text IS NOT NULL)
// WITH b.id as bookId, b.text as origText, 4000 as chunkSize, 400 as overlap, size(b.text) as textLength
// WITH bookId, origText, chunkSize,  overlap, toInteger(ceil(1.0*textLength/chunkSize)) as totalChunks
// CALL (bookId, origText, chunkSize, overlap, totalChunks) {
//   UNWIND range(0, totalChunks-1) AS indexStart
//   WITH indexStart, bookId, origText as text, chunkSize, overlap, 
//     CASE (indexStart)
//     WHEN 0 THEN overlap
//     ELSE indexStart*chunkSize
//   END AS subStart
//   MATCH (b:Book {id: bookId})
//   CREATE (c:Chunk {id: indexStart, text: substring(text, subStart-overlap, subStart+chunkSize+overlap)})
//   MERGE (b)-[:HAS_CHUNK]->(c)
// } IN TRANSACTIONS OF 100 ROWS;

//Generate embeddings for Book nodes (Ollama)
CYPHER 25
MATCH (b:Book)
WHERE b.text IS NOT NULL 
AND b.embedding IS NULL
AND b.title IS NOT NULL
CALL (b) {
    WITH b, substring(b.title+"\n"+b.text,0,1000) as bookText
    WITH ai.text.embed(bookText, 'openai', 
        { token: "", model: 'nomic-embed-text:latest', vendorOptions: { dimensions: 768 } }) as vector
    SET b.embedding = vector
} IN TRANSACTIONS OF 5 ROWS
ON ERROR CONTINUE;

//Generate embeddings for Review nodes (Ollama)
CYPHER 25
MATCH (r:Review)
WHERE r.text IS NOT NULL 
AND r.embedding IS NULL
CALL (r) {
    WITH r, substring(r.text,0,1000) as reviewText
    WITH ai.text.embed(reviewText, 'openai', 
        { token: "", model: 'nomic-embed-text:latest', vendorOptions: { dimensions: 768 } }) as vector
    SET r.embedding = vector
} IN TRANSACTIONS OF 5 ROWS
ON ERROR CONTINUE;

// To delete all the data:
// // Delete all relationships 
// MATCH ()-[r]-() 
// CALL (r) {
//  DELETE r 
// } IN TRANSACTIONS OF 10000 ROWS;

// // Delete all nodes
// MATCH (n) 
// CALL (n) {
//  DETACH DELETE n 
// } IN TRANSACTIONS OF 10000 ROWS;