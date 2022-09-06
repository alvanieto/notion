import std/[httpclient, json, strformat, times]

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
  client = newHttpClient()

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
    response = client.request(base_url & fmt"databases/{database_id}/query", httpMethod = HttpPost, body = $payload)

  return parseJson(response.body)["results"]

proc isAnOldCard(whenStr: string, today: string): bool =
  result = false
  if whenStr != "":
    result = whenStr[0..9] < today

proc fixStartDate(whenDate: string): string =
  let newDate = parse(whenDate, isoformat)
  return format(newDate, isoformat)

proc updateCard(pageId: string, data: JsonNode) =
  let payload = %*{"properties": data}
  discard client.request(base_url & fmt"pages/{pageId}", httpMethod = HttpPatch, body = $payload)

proc main() =
  client.headers = headers
  let today = (now() + 1.days).getDateStr()
  for card in getToDoCards().items():
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

      updateCard(card["id"].getStr(), newData)

when isMainModule:
  let ini = getTime()
  main()
  echo fmt"Time:{getTime() - ini}"
