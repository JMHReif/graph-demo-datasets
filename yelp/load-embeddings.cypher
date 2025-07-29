//LLM api key
:params {apiKey: "<YOUR API KEY HERE>"};

//Vector index
CREATE VECTOR INDEX `review-embedding-index` IF NOT EXISTS 
FOR (r:Review) ON (r.embedding)
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}};

//Generate embeddings for Place nodes (batched)
MATCH (r:Review WHERE r.text IS NOT NULL AND r.embedding IS NULL)-[rel:WRITTEN_FOR]->(b:Business)
WITH b, collect(r) AS reviewList,
     count(*) AS total,
     100 AS batchSize
UNWIND range(0, total-1, batchSize) AS batchStart
CALL (b, reviewList, batchStart, batchSize) {
    WITH [review IN reviewList[batchStart .. batchStart + batchSize] | b.name+"\n"+review.text] AS batch
    CALL genai.vector.encodeBatch(batch, 'OpenAI', { token: $apiKey, model: "text-embedding-3-small" }) YIELD index, vector
    CALL db.create.setNodeVectorProperty(reviewList[batchStart + index], 'embedding', vector)
} IN CONCURRENT TRANSACTIONS OF 1 ROW;