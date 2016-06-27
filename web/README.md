# Web Application for Author Disambiguation

To run:

 - Install NodeJS
 - Create the file `db_login.json` in the root directory:
```
{
  "dbname" : "DB_NAME",
  "host" : "IP_OR_URL",
  "port" : PORT,
  "user" : "USER_NAME", 
  "password" : "PASSWORD"
}
```
 - In the `web` directory run:
	 - `npm install`
 - Create a config file `web/config.json` with the following template:
```
{
	"clientId": ****,
	"clientSecret": "<secret>",
	"localhostUrl": "<localhost or IP>"
}
```
 - Run the application
	 - `node .`
