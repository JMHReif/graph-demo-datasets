//Possible queries to run for demo:
//pull back the entire graph
MATCH (n)-[r:PLAYED|APPEARS_IN]-(n2) RETURN n, r, n2;

//retrieve all the Movie nodes we have
MATCH (n:Movie) RETURN n;

//filter Movies by date after 2000
MATCH (m:Movie)
WHERE m.releaseDate > date('2000-01-01')
RETURN m;

//filter Movies by date after 2000 and return properties for table results
MATCH (m:Movie)
WHERE m.releaseDate > date('2000-01-01')
RETURN m.title, m.releaseDate;

//filter Movies by the trilogy (FotR, TT, RotK)
MATCH (m:Movie)
WHERE m.title IN ["The Lord of the Rings: The Fellowship of the Ring", "The Lord of the Rings: The Two Towers", "The Lord of the Rings: The Return of the King"]
RETURN m;

WITH ["The Lord of the Rings: The Fellowship of the Ring", "The Lord of the Rings: The Two Towers", "The Lord of the Rings: The Return of the King"] as movies
MATCH (m:Movie)
WHERE m.title IN movies
RETURN m;

//find all the characters who appear in The Return of the King
MATCH (m:Movie {title: 'The Lord of the Rings: The Return of the King'})<-[r:APPEARS_IN]-(c:Character)
RETURN m, r, c;

//find all the cast who played those characters in The Return of the King
MATCH (m:Movie {title: 'The Lord of the Rings: The Return of the King'})<-[r:APPEARS_IN]-(c:Character)<-[r2:PLAYED]-(a:Cast)
RETURN m, r, c, r2, a;

//pull back entire graph for 3 movies (organize)
WITH ["The Lord of the Rings: The Fellowship of the Ring", "The Lord of the Rings: The Two Towers", "The Lord of the Rings: The Return of the King"] as movies
MATCH (m:Movie)<-[r:APPEARS_IN]-(c:Character)<-[r2:PLAYED]-(a:Cast)
WHERE m.title IN movies
RETURN m, r, c, r2, a;

//see if an actor played multiple Characters
WITH ["The Lord of the Rings: The Fellowship of the Ring", "The Lord of the Rings: The Two Towers", "The Lord of the Rings: The Return of the King"] as movies
MATCH (m:Movie)<-[r:APPEARS_IN]-(c:Character)<-[r2:PLAYED]-(a:Cast)
WHERE m.title IN movies
WITH m, r, c, r2, a
WHERE size((a)-[:PLAYED]->(:Character)) > 1
RETURN m, r, c, r2, a;

//see if Characters were played by same actor
WITH ["The Lord of the Rings: The Fellowship of the Ring", "The Lord of the Rings: The Two Towers", "The Lord of the Rings: The Return of the King"] as movies
MATCH (m:Movie)<-[r:APPEARS_IN]-(c:Character)<-[r2:PLAYED]-(a:Cast)
WHERE m.title IN movies
WITH m, r, c, r2, a
WHERE size((c)<-[:PLAYED]-(:Cast)) > 1
RETURN m, r, c, r2, a;