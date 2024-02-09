from langchain_openai import OpenAIEmbeddings
import os
from neo4j import GraphDatabase, Result
import pandas

host = "<NEO4J_URI>"
user = "<NEO4J_USERNAME>"
password = "<NEO4J_PASSWORD>"
database = "<NEO4J_DATABASE>"
openai_key = "<OPENAI_API_KEY>"

embeddings = OpenAIEmbeddings(openai_api_key=openai_key)

vector_index_query = """
CREATE VECTOR INDEX `spring-ai-document-index` IF NOT EXISTS 
FOR (r:Review) ON (r.embedding)
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}}
"""

embeddings_query = """
    MATCH (r:Review)
    WHERE r.embedding IS NULL
    RETURN r.id as id, coalesce(r.review_text,'') as reviewText
"""

embeddings_update = """
    MATCH (r:Review {review_id:$reviewId})
    CALL db.create.setNodeVectorProperty(r, 'embedding', $embedding)
    RETURN count(*) as updated
"""
with GraphDatabase.driver(host, auth=(user, password)) as driver:
    driver.verify_connectivity()
    driver.execute_query(vector_index_query, database=database)

    records, _, _ = driver.execute_query(embeddings_query, database=database )

# Loop through results, compute the embedding and update the record
    for record in records:
        id = record.get('id')
        text = record.get('reviewText')
        emb = embeddings.embed_query(text)
        print(id, text, emb[0:5])
        success, summary , _ = driver.execute_query(embeddings_update, database=database, reviewId=id, embedding=emb)
        print(success, summary.counters)