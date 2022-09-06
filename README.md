# Description

Small program to move automatically notion cards in a kanban like database from a "To Do" column to a "Heute" one.

There are two versions a sync and an async one (faster).

# Configuration

You must set the database_id and your secret token. Also you can tweak the from and to columns

# Create the executable

```bash
nim c -d:release -d:ssl notion.nim
nim c -d:release -d:ssl notion_async.nim
```
