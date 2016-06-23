'use strict';
let config = JSON.parse(require('fs').readFileSync(__dirname + '/../../db_login.json'));

module.exports = {
  "db": {
    "name": "db",
    "connector": "memory"
  },
	"ArticlesDB": {
		"host": config.host,
    "port": config.port,
    "database": config.dbname,
    "user": config.user,
    "password": config.password,
    "name": "ArticlesDB",
    "connector": "postgresql"
	}
}