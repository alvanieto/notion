import asyncdispatch
import std/[httpclient, json, strformat, sugar, times]

const
  database_id = ""
  token = ""
  base_url = "https://api.notion.com/v1/"
  isoformat = "yyyy-MM-dd'T'HH:mm:ss'.'fffzzz"

let 
  headers = newHttpHeaders({
    "Content-Type": "application/json",
    "Accept": "application/json",
    "Authorization": fmt"Bearer {token}",
    "Notion-Version": "2021-08-16"
  })

proc getToDoCards(): JsonNode =
  let 
    payload = %*{
      "page_size": 100,
      "filter": %*{
        "property": "^OE@",
        "select": %*{
          "equals": "To Do"
        }
      }
    }
    client = newHttpClient(headers=headers)
    response = client.request(base_url & fmt"databases/{database_id}/query", httpMethod = HttpPost, body = $payload)

  let body = parseJson(response.body)
  if response.status != "200 OK":
    echo body
    raise newException(Exception, body["code"].getStr)
  return body["results"]

proc isAnOldCard(whenStr: string, today: string): bool =
  result = false
  if whenStr != "":
    result = whenStr[0..9] < today

proc fixStartDate(whenDate: string): string =
  let newDate = parse(whenDate, isoformat)
  return format(newDate, isoformat)

proc updateCard(pageId: string, data: JsonNode): Future[AsyncResponse] =
  let
    payload = %*{"properties": data}
    client_async = newAsyncHttpClient(headers=headers)
  client_async.request(base_url & fmt"pages/{pageId}", httpMethod = HttpPatch, body = $payload)

proc processCard(today: string, card: JsonNode): Future[AsyncResponse] =
  let
    properties = card["properties"]
    whenDate = properties["When"]["date"]
    start = (if whenDate.kind != JNull: whenDate["start"].getStr("") else: "")

  if isAnOldCard(start, today):
    let title = properties["Name"]["title"][0]["plain_text"]
    var newData = %*{"Status": %*{"select": %*{"name": "Heute"}}}
    echo fmt"Card moved from 'To Do' to 'Heute': {title} / {start}"

    if whenDate["end"].kind != JNull:
      echo "\tRemoving end date, increasing start_date by 2 hours and adding a reminder"
      newData["When"] = %*{"date": %*{"end": nil, "start": fixStartDate(start)}}

    return updateCard(card["id"].getStr(), newData)

proc main() {.async.} =
  let
    today = (now() + 1.days).getDateStr()
    futures = collect(for card in getToDoCards().items():
      processCard(today, card))
  for future in futures:
    if future != nil:
      discard await future

when isMainModule:
  let ini = getTime()
  waitFor main()
  echo fmt"Time: {getTime() - ini}"
