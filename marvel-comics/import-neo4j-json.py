# import dependency packages
import sys
import hashlib
import math
from py2neo import Graph                       # install with `pip install py2neo`
import requests                                # `pip install requests`
from ratelimit import limits                   # `pip install ratelimit`
from datetime import datetime
import json
import time

#variables
url_prefix = 'https://gateway.marvel.com:443/'
TWENTYFOUR_HOURS = 86400
MAX_RETRIES = 3
callCount = 0
skipVal = 0

@limits(calls=3000, period=TWENTYFOUR_HOURS)
def call_marvel_api(url):
    timestamp = datetime.now()
    timestamp_str = timestamp.strftime("%Y%m%d %H:%M:%S")
    public_api_key = '<your_public_API_key_here>'
    private_api_key = '<your_private_API_key_here>'
    hashVal = hashlib.md5((timestamp_str + private_api_key + public_api_key).encode('utf-8')).hexdigest()
    full_url = url + '&ts=' + timestamp_str + '&apikey=' + public_api_key + '&hash=' + hashVal
    #print('Full URL: ', full_url)

    session = requests.Session()
    adapter = requests.adapters.HTTPAdapter(max_retries=MAX_RETRIES)
    session.mount('https://', adapter)
    session.mount('http://', adapter)

    r = session.get(full_url)
    response = json.loads(r.content)

    if r.status_code != 200:
        raise Exception('API response: {}'.format(r.text))
    
    return response['data']

def retrieve_entities(entity):
    #note: entity must be plural - characters, comics, creators, events, series, stories
    global url_prefix, skipVal, callCount
    if entity == 'characters' or entity == 'events':
        orderField = 'name'
    elif entity == 'comics' or entity == 'series':
        orderField = 'title'
    elif entity == 'creators':
        orderField = 'lastName'
    elif entity == 'stories':
        orderField = 'id'
    
    url_suffix = url_prefix + 'v1/public/' + entity + '?orderBy=' + orderField + '&limit=100&offset='

    #make initial call to retrieve stats
    url = url_suffix + str(skipVal)
    data = call_marvel_api(url)
    callCount = 1

    #calc how many more times to call
    totalEntities = data['total']
    callsNeeded = int(math.ceil(totalEntities / 100))
    print('Total ', entity, ': ', totalEntities)
    print('Calls needed: ', callsNeeded)
    trimmedData = {
            "total": totalEntities,
            str(entity): []
    }

    print('Adding ', entity, ' data to file...')
    for num in range(callsNeeded):
        url = url_suffix + str(skipVal)
        data = call_marvel_api(url)

        #trim unwanted data
        entities = data['results']
        for element in entities:
            if entity == 'characters':
                others = ['comics', 'series', 'stories', 'events']
            elif entity == 'comics':
                others = ['characters', 'creators', 'stories', 'events']
            elif entity == 'creators':
                others = ['comics', 'series', 'stories', 'events']
            elif entity == 'events':
                others = ['creators', 'characters', 'stories', 'comics', 'series']
            elif entity == 'series':
                others = ['creators', 'characters', 'stories', 'comics', 'events']
            elif entity == 'stories':
                others = ['creators', 'characters', 'series', 'comics', 'events']
            
            for item in others:
                del element[item]['items']
                del element[item]['returned']
            
            trimmedData[entity].append(element)

        #increment offset to pull next API results
        skipVal = skipVal + 100

        callCount = callCount + 1
        print('Call progress: ', callCount)

    with open(entity + '.json', 'a') as entityFile:
        json.dump(trimmedData, entityFile, indent=4)

def retrieve_relationships(entity):
    global url_prefix, skipVal, callCount
    #entity only comics, creators, events, series, stories (characters are start nodes)
    if entity == 'creators':
        startNode = 'creator'
        orderField = 'lastName'
    else:
        startNode = 'character'
        if entity == 'comics' or entity == 'series':
            orderField = 'title'
        elif entity == 'events':
            orderField = 'name'
        elif entity == 'stories':
            orderField = 'id'

    #format singular text of each entity as endNode
    if entity == 'stories':
        endNode = 'story'
    elif entity == 'series':
        endNode = entity
    else:
        endNode = entity.rstrip('s')
    print('StartNode: ', startNode, ' EndNode: ', endNode)

    url_suffix = '/' + entity + '?orderBy=' + orderField + '&limit=100&offset='
    
    fileData = read_file(entity, startNode)
    #print('RelationshipData: ', fileData)

    endNodeRels = str(endNode)+'Rels'
    trimmedData = {
        "entitiesWithRels": fileData['startNodeNum'],
        endNodeRels: []
    }
    print('Entities to call relationships: ', fileData['startNodeNum'])
    totalCalls = fileData['totalCalls']
    print('Expected calls: ', totalCalls)

    if totalCalls < 3000:
        for item in fileData['relationships']:
            skipVal = 0
            startNodeIdStr = str(startNode)+'Id'
            endNodeIdList = str(endNode)+'Ids'
            startNodeId = str(item[startNodeIdStr])
            callsNeeded = int(item['callsNeeded'])
            callCount = callCount + int(callsNeeded)
            relData = {
                startNodeIdStr: item[startNodeIdStr],
                "numAvailable": item['num_available'],
                endNodeIdList: []
            }
            
            #print("Adding relationship data to file...")
            for num in range(callsNeeded):
                url = url_prefix + 'v1/public/' + str(fileData['url_entity']) + startNodeId + url_suffix  + str(skipVal)

                data = call_marvel_api(url)
                dataList = data['results']

                #trim unwanted data
                for element in dataList:
                    endNodeId = str(endNode)+'Id'
                    elementId = {
                        endNodeId: element['id']
                    }
                    relData[endNodeIdList].append(elementId)

                skipVal = skipVal + 100

            print(startNodeIdStr, ': ', startNodeId, ' Progress: ', callCount, '/', totalCalls)
            trimmedData[endNodeRels].append(relData)

        fileName = str(startNode + entity) + '.json'
        with open(fileName, 'a') as relFile:
            json.dump(trimmedData, relFile, indent=4)

        print('Number called: ', callCount)
    else:
        print("PAUSE! Halting processing to avoid call limit overage")
        sys.exit(0)

def read_file(entity, startNode):
    #build url based on file data
    if entity == 'creators':
        #temp set entity, pull creator comics from smaller side
        entity = 'comics'
        with open('creators.json', 'r') as entityFile:
            fileData = json.load(entityFile)
            data = fileData['creators']
    else:
        with open('characters.json', 'r') as entityFile:
            fileData = json.load(entityFile)
            data = fileData['characters']
    
    url_entity = startNode + 's/'
    totalCalls = 0
    startNodeNum = 0
    jsonObject = {
        "startNodeNum": startNodeNum,
        "url_entity": url_entity,
        "totalCalls": totalCalls,
        "relationships": []
    }

    for item in data:
        entityId = item['id']
        num_available = item[entity]['available']
            
        if num_available > 0:
            startNodeNum += 1
            callsNeeded = int(math.ceil(num_available / 100))
            totalCalls = totalCalls + callsNeeded
            #print("EntityId: ", entityId, " Calls needed: ", callsNeeded)

            details = {
                str(startNode)+"Id": entityId,
                "num_available": num_available,
                "callsNeeded": callsNeeded
            }
            jsonObject['relationships'].append(details)
    
    jsonObject['startNodeNum'] = startNodeNum
    jsonObject['totalCalls'] = totalCalls
    return jsonObject

if __name__ == '__main__':
    globals()[sys.argv[1]](sys.argv[2])