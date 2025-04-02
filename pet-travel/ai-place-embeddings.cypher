//Vector index
CREATE VECTOR INDEX `place-descr` IF NOT EXISTS
FOR (p:Place) ON p.embedding
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}};

//Generate embeddings for Place nodes (batched)
MATCH (p:Place WHERE p.description IS NOT NULL AND p.embedding IS NULL)
WITH collect(p) AS placesList,
     count(*) AS total,
     100 AS batchSize
UNWIND range(0, total-1, batchSize) AS batchStart
CALL (placesList, batchStart, batchSize) {
    WITH [place IN placesList[batchStart .. batchStart + batchSize] | place.name+"\n"+place.description] AS batch
    CALL genai.vector.encodeBatch(batch, 'OpenAI', { token: $token, model: "text-embedding-3-small" }) YIELD index, vector
    CALL db.create.setNodeVectorProperty(placesList[batchStart + index], 'embedding', vector)
} IN CONCURRENT TRANSACTIONS OF 1 ROW;