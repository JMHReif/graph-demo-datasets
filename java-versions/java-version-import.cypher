//Github project source: https://raw.githubusercontent.com/marchof/java-almanac/

//Setup:
CREATE INDEX java_version FOR (j:JavaVersion) ON (j.version);

//Queries:
//1) Load Java versions, along with related sources, features, and refs
WITH [1.0,1.1,1.2,1.3,1.4,5,6,7,8,9,10,11,12,13,14,15,16,17,18] as versions
CALL apoc.periodic.iterate('UNWIND $versions as version RETURN version',
    'CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+".json")
    YIELD value
    MERGE (j:JavaVersion {version: value.version})
     ON CREATE SET j.name = value.name, j.codeName = value.codename, 
     j.gaDate = date(apoc.date.convertFormat(value.ga,"yyyy/MM/dd","iso_date")), j.status = value.status, j.bytecode = value.bytecode, 
     j.vmSpec = value.documentation.vm, j.languageSpec = value.documentation.lang, 
     j.apiSpec = value.documentation.api 
    WITH value, j 
    WHERE value.scm IS NOT NULL 
    UNWIND value.scm as scm 
    MERGE (s:SourceCode {type: scm.type}) 
     ON CREATE SET s.sourceURL = scm.url 
    MERGE (j)-[r:MANAGED_BY]-(s) 
    WITH value, j 
    WHERE value.features IS NOT NULL 
    UNWIND value.features as feature 
    MERGE (f:Feature {title: feature.title}) 
     ON CREATE SET f.category = feature.category 
    WITH value, j, feature, f 
    CALL { 
        WITH f, feature 
        UNWIND feature.refs as ref 
        MERGE (r:Reference {id: ref.identifier}) 
         ON CREATE SET r.type = ref.type 
        MERGE (f)-[r3:HAS]->(r) 
        RETURN r 
    }
    WITH value, j, f
    MERGE (j)-[r2:INCLUDES]->(f)',
    {batchSize: 50, iterateList:false, params:{versions:versions}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: 237
//Total rels: 506

//2) Load Java version diffs for each version - 1.2
WITH 1.2 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString($startVersion)}) 
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) 
    RETURN start, collect(prev.version) as prevVersions', 
    'UNWIND prevVersions as prevVersion 
    CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+start.version+"/apidiff/"+prevVersion+".json") 
    YIELD value 
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version}) 
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor 
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev) 
    WITH value, d 
    WHERE value.deltas IS NOT NULL
    CALL {
        WITH value, d
        UNWIND value.deltas as level1Delta
        WITH d, level1Delta 
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags}) 
        YIELD node
        MERGE (d)-[r3:CONTAINS]->(node)
        WITH level1Delta, node
        WHERE level1Delta.deltas IS NOT NULL
        CALL { 
            WITH level1Delta, node
            UNWIND level1Delta.deltas as level2Delta 
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}) 
            YIELD node as node2
            WITH level2Delta, node, node2 
            MERGE (node)-[r4:CONTAINS]->(node2) 
            WITH level2Delta, node2
            WHERE level2Delta.deltas IS NOT NULL
            CALL {
                WITH level2Delta, node2
                UNWIND level2Delta.deltas as level3Delta 
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}) 
                YIELD node as node3
                WITH level3Delta, node2, node3 
                MERGE (node2)-[r5:CONTAINS]->(node3)
                RETURN count(*)
            } 
            RETURN count(*)
        } 
        RETURN count(*)
    } 
    RETURN count(*)', {batchSize: 500, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//3) Load Java version diffs for each version - 1.3
WITH 1.3 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//4) Load Java version diffs for each version - 1.4
WITH 1.4 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//5) Load Java version diffs for each version - 5
WITH 5 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//6) Load Java version diffs for each version - 6
WITH 6 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//7) Load Java version diffs for each version - 7
WITH 7 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//8) Load Java version diffs for each version - 8
WITH 8 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//9) Load Java version diffs for each version - 9
WITH 9 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//10) Load Java version diffs for each version - 10
WITH 10 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//11) Load Java version diffs for each version - 11
WITH 11 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//12) Load Java version diffs for each version - 12
WITH 12 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//13) Load Java version diffs for each version - 13
WITH 13 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//14) Load Java version diffs for each version - 14
WITH 14 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//15) Load Java version diffs for each version - 15
WITH 15 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//16) Load Java version diffs for each version - 16
WITH 16 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//17) Load Java version diffs for each version - 17
WITH 17 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?

//18) Load Java version diffs for each version - 18
WITH 18 as startVersion
CALL apoc.periodic.iterate('MATCH (start:JavaVersion {version: toString(startVersion)})
    MATCH (prev:JavaVersion) WHERE 1.0 < toFloat(prev.version) < toFloat(start.version) RETURN start, collect(prev.version) as prevVersions',
    'UNWIND prevVersions as prevVersion CALL apoc.load.json("https://raw.githubusercontent.com/marchof/java-almanac/master/site/data/jdk/versions/"+version+"/apidiff/"+prevVersion+".json")
    YIELD value
    MERGE (d:VersionDiff {fromVersion: value.base.version, toVersion: value.target.version})
     ON CREATE SET d.fromVendor = value.base.vendor, d.toVendor = value.target.vendor
    MERGE (start)-[r:FROM_NEWER]->(d)-[r2:TO_OLDER]->(prev)
    WITH value, d
    CALL {
        WITH value, d
        WHERE value.deltas IS NOT NULL
        UNWIND value.deltas as level1Delta
        CALL apoc.merge.node([apoc.text.capitalize(level1Delta.type)], {name: level1Delta.name, status: level1Delta.status, docURL: level1Delta.javadoc, tags: level1Delta.addedTags},{}) YIELD node
        WITH value, level1Delta, d, node
        MERGE (d)-[r3:CONTAINS]->(node)
        CALL {
            WITH value, level1Delta, node
            WHERE level1Delta.deltas IS NOT NULL
            UNWIND leve1Delta.deltas as level2Delta
            CALL apoc.merge.node([apoc.text.capitalize(level2Delta.type)], {name: level2Delta.name, status: level2Delta.status, docURL: level2Delta.javadoc, tags: level2Delta.addedTags}, {}) YIELD node2
            WITH value, level2Delta, node, node2
            MERGE (node)-[r4:CONTAINS]->(node2)
            CALL {
                WITH value, level2Delta, node2
                WHERE level2Delta.deltas IS NOT NULL
                UNWIND level2Delta.deltas as level3Delta
                CALL apoc.merge.node([apoc.text.capitalize(level3Delta.type)], {name: level3Delta.name, status: level3Delta.status, docURL: level3Delta.javadoc, tags: level3Delta.addedTags}, {}) YIELD node3
                WITH value, level3Delta, node2, node3
                MERGE (node2)-[r5:CONTAINS]->(node3)
            }
        }
    }', {batchSize: 50, iterateList:false, params:{startVersion:startVersion}})
YIELD batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated
RETURN batches, total, timeTaken, committedOperations, failedOperations, failedBatches , retries, errorMessages , batch , operations, wasTerminated;
//Total nodes: ?
//Total rels: ?