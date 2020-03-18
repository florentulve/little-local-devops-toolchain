const http = require('http')
const port = process.env.PORT || 8080

let index_page = `
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="x-ua-compatible" content="ie=edge">
    <title>Hello World!</title>
    <meta name="description" content="">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        .container { min-height: 100vh; display: flex; justify-content: center; align-items: center; text-align: center; }
        .title { font-family: "Source Sans Pro", "Helvetica Neue", Arial, sans-serif; display: block; font-weight: 300; font-size: 100px; color: #35495e; letter-spacing: 1px; }
        .subtitle { font-family: "Source Sans Pro", "Helvetica Neue", Arial, sans-serif; font-weight: 300; font-size: 42px; color: #526488; word-spacing: 5px; padding-bottom: 15px; }
        .links { padding-top: 15px; }
    </style>
  </head>
  <body>
    <section class="container">
      <div>
        <h1 class="title">
          👋 Hey 🐳
        </h1>
        <h2 class="subtitle">
          made with 😍 by @k33g_org
        </h2>        
      </div>
    </section>
  </body>
</html>  
`

const requestHandler = (request, response) => {
  console.log(request.url)
  response.writeHead(200, {'Content-Type': 'text/html; charset=utf-8'})
  response.end(index_page)
}

const server = http.createServer(requestHandler)

server.listen(port, (err) => {
  if (err) {
    return console.log('😡 something bad happened', err)
  }
  console.log(`🌍 server is listening on ${port}`)
})




