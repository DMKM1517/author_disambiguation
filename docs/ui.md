
# Web User Interface

The Web User Interface is built on [NodeJS](https://nodejs.org/) using the framework [StrongLoop](https://strongloop.com/) on the server side and [AngularJS](https://angular.io/) on the client side. It is connected to [PostgreSQL](https://www.postgresql.org/) for managing the data.

The versions are:

 - NodeJS: 4.4.1
 - PostgreSQL: 9.5
 - For the frameworks and other libraries, check the files `package.json` and `index.html`

## Structure

The folder is called 	`web` and its structure is the following:
```
web
|___ client
	|___ css
		|   styles.css
	|___ img
		|   ...
	|___ js
		|   app.js
		|   controllers.js
	|___ templates
		|   about.html
		|   home.html
	|___ vendor
		|___ mendeley
			|   standalone.min.js
			|   standalone.min.js.map
	|   index.html
|___ common
	|___ models
		|   article.js
		|   article.json
|___ server
	|___ boot
		|   authentication.js
		|   routes.js
	|   component-config.json
	|   config.json
	|   datasources.json
	|   datasources.local.js
	|   middleware.json
	|   middleware.production.json
	|   model-config.json
	|   server.js
|   config.json
|   package.json
|   README.md
|   ...
```

Some comments about the structure:

 - The `client` folder contains the client side logic. 
	 - It is a simple Angular application, with the main file `app.js` and the controllers.
	 - There is a folder containing the Mendeley Javascript SDK.
	 - There are other libraries loaded via CDN.
 - There is only one model: the Articles.
 - The `server` folder is the server side logic.
	 - The `boot/routes.js` file contains the routes mainly for login with Mendeley.
	 - The `datasources.json` file is empty with just the schema in order to use the `datasources.local.js`
	 - The `datasources.local.js` file reads the file `db_login.json` from the directory of the project (above the `web`) and creates the connection.
	 - In the `server.js` file, the app starts using [socket.io](http://socket.io/) to update the status of the process.
 - The `config.json` file contains the Mendeley API key.
	 - `clientId`: Id of 4 numbers
	 - `clientSecret`: secret string
	 - `localhostUrl`: base domain to redirect


## Process

 1. The user fills the form with the article's data
	 - Optionally, login with Mendeley and select an article
	 - Complete the missing fields
 2. Send the form asynchronously
	 - The server inserts the data in the corresponding tables
	 - It returns the Process ID
 3. The client emits the event to start processing with the Process ID
 4. The server creates a child process to run Rscript
	 - It runs the main script `Operational/Process_Web_Article.R`
	 - It emits the relevant output
	 - The client updates the progress
 5. When the processing is done
	 - The server queries the final results and emits them
	 - The client presents the results
 6. In case of error
	 - The server emits the error
	 - The client notifies the error

## Deployment

### Install PostgreSQL

Follow any guide, for example the [official one for Ubuntu](https://www.postgresql.org/download/linux/ubuntu/), or follow these steps:

 - Create the file `/etc/apt/sources.list.d/pgdg.list`, and add a line for the repository
`deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main`
 - Import the repository running
	 - `wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
	  sudo apt-key add -`
	 - `sudo apt-get update`
 - Install postgresql
	 - `sudo apt-get install postgresql-9.5`

Now, make the database accesible:

 - Change to postgres user
	`sudo su - postgres`
 - Change these config files using `vi` or any other editor
	 - `vi /etc/postgresql/9.5/main/postgresql.conf`
		Change this line `listen_addresses = '*'`
	 - `vi /etc/postgresql/9.5/main/pg_hba.conf`
		Change this line `host all all 0.0.0.0/0 md5`
 - Reload configuration and restart
	 - `psql`
	 - `SELECT pg_reload_conf();`
	 - `\q`
	 - `service postgresql restart`

Create a user and the database:

 - `psql`
 - `create user <user> with password '<password>';`
 - `create database <database> with owner <user> encoding 'UTF8';`



### Install NodeJS

Install NodeJS downloading from its [site](https://nodejs.org/en/download/) or:

 - On Ubuntu
	 - `curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -`
	 - `sudo apt-get install -y nodejs`
 - On Centos (as root)
	 - `curl --silent --location https://rpm.nodesource.com/setup_4.x | bash -`
	 - `yum -y install nodejs`

Install StrongLoop

 - `sudo npm install -g strongloop`

Install PM2

 - `sudo npm install -g pm2`


### Initialize the application

 - Clone (or update if this was already done) the github repository https://github.com/DMKM1517/author_disambiguation.git
 - Install the dependencies for the web
	 - `cd web`
	 - `npm install`
 - Run the server using PM2
	 - `pm2 start . --name web`
 - Save the process to startup
	 - `pm2 startup`
	 - (copy and execute the output line)
	 - `pm2 save`
 - The default port is `3000`. To change it, modify the file `server/config.json`.


### Update the application

 - On the github directory
	 - `git pull`
	 - (make any modifications if needed)
 - Restart the server
	`pm2 restart web`
	 - Check the logs
		`pm2 logs web`
