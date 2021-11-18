//Load User files 1-29 with all related entities
UNWIND range(1,29) as number
WITH number, split(toString(round(rand()*10000)),'.') as genId
MERGE (u:User {id: genId[0], name: 'User'+number})
WITH u, number
LOAD CSV WITH HEADERS FROM 'file:///User'+number+'.csv' as file
WITH file, u, split(toString(round(rand()*10000)),'.') as genId2, split(file.`Region/Game Code`,' / ') as regioncode
MERGE (s:GameSession {region: regioncode[0], gameCode: regioncode[1]})
 SET s.id = genId2[0]
WITH file, u, s
MERGE (u)-[:JOINS]->(s)
WITH file, s, split(toString(round(rand()*10000)),'.') as genId3
MERGE (g:Game {length: file.`Game Length`, completedDate: file.`Game Completed Date`})
 SET g.id = genId3[0]
MERGE (s)-[:INCLUDES]->(g)
WITH file, g, split(toString(round(rand()*10000)),'.') as genId4
MERGE (c:Character {id: genId4[0]})
 ON CREATE SET c.completedTasks = file.`Task Completed`, 
 c.fixedSabotages = file.`Sabotages Fixed`, c.murdered = file.Murdered, 
 c.allTasksCompleted = file.`All Tasks Completed`, 
 c.allTasksCompletedTime = file.`Time to complete all tasks`, 
 c.imposterKills = file.`Imposter Kills`, 
 c.outcome = file.Outcome, c.rankChange = file.`Rank Change`, 
 c.teamAssigned = file.Team, c.ejected = file.Ejected
MERGE (g)-[:HAS_PARTICIPANT]->(c);