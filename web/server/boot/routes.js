module.exports = function(app) {
	'use strict';

	const fs = require('fs');
	var config = JSON.parse(fs.readFileSync(__dirname + '/../../config.json'));
	var oauth2 = require('simple-oauth2')({
		site: 'https://api.mendeley.com',
		clientID: config.clientId,
		clientSecret: config.clientSecret
	});

	var accessTokenCookieName = 'accessToken';
	var refreshTokenCookieName = 'refreshToken';
	var oauthPath = '/oauth';
	var tokenExchangePath = '/oauth/token-exchange';
	var port = JSON.parse(fs.readFileSync(__dirname + '/../config.json')).port;
	var redirectUri = 'http://' + config.localhostUrl + ':' + port + tokenExchangePath;

	app.get('/login', function(req, res) {
		res.clearCookie(accessTokenCookieName);
		res.clearCookie(refreshTokenCookieName);
		res.redirect(oauthPath);
	});

	app.get(oauthPath, function(req, res) {
		let authorizationUri = oauth2.authCode.authorizeURL({
			redirect_uri: redirectUri,
			scope: config.scope || 'all'
		});
		res.redirect(authorizationUri);
	});

	app.get(tokenExchangePath, function(req, res, next) {
		var code = req.query.code;
		oauth2.authCode.getToken({
			redirect_uri: redirectUri,
			code: code,
		}, function(error, result) {
			if (error) {
				console.log('Error exchanging token');
				res.redirect('/')
			} else {
				setCookies(res, result);
				res.redirect('/');
			}
		});
	});

	app.get('/oauth/refresh', function(req, res, next) {
		var cookies = req.cookies,
			json = '{ message: "unknown error"}',
			status;
		res.set('Content-Type', 'application/json');
		// No cookies? Don't bother trying to refresh and send a 401
		if (!cookies[refreshTokenCookieName]) {
			console.log('Cannot refresh as no refresh token cookie available');
			status = 401;
			json = '{ message: "Refresh token unavailable" }';
			res.status(status).send(json);
		}
		// Otherwise attempt refresh
		else {
			oauth2.AccessToken.create({
				access_token: cookies[accessTokenCookieName],
				refresh_token: cookies[refreshTokenCookieName]
			}).refresh(function(error, token) {
				// On error send a 401
				if (error) {
					status = 401;
					json = '{ message: "Refresh token invalid" }';
				}
				// Otherwise put new access/refresh token in cookies and send 200
				else {
					status = 200;
					setCookies(res, token.token);
					json = '{ message: "Refresh token succeeded" }';
				}
				console.log('Refresh result:', status, json);
				res.status(status).send(json);
			});
		}
	});

	app.get('/getSubjects', function(req, res) {
		let query = `select distinct subject
			from source.subjects
			order by subject;`;
		app.dataSources.ArticlesDB.connector.execute(query, function(err, results) {
			res.json(results);
		});
	});

	app.get('/test', function(req, res) {
		let query = `
              select
	aa1.d as d1,
	a2.title,
  aa2.author
from
	source.articles a
	join main.same_authors sa on a.id = sa.id1
	join main.articles_authors aa1 on sa.id1 = aa1.id and sa.d1 = aa1.d
	left join main.articles_authors aa2 on sa.id2 = aa2.id and sa.d2 = aa2.d
	left join source.articles a2 on sa.id2 = a2.id
where
	a.processid = 10014
	and sa.same is true
order by aa1.id, aa1.d, aa2.id, aa2.d
limit 500;
            	`;
            app.dataSources.ArticlesDB.connector.execute(query, function(err, results) {
              let disambiguated = [];
              for (let i = 0; i < new Set(results.map(x => x.d1)).size; i++) {
                disambiguated.push(results.filter(x => x.d1 == i));
              }
              res.json(disambiguated);
            });
	})

	function setCookies(res, token) {
		res.cookie(accessTokenCookieName, token.access_token, {
			maxAge: token.expires_in * 1000
		});
		res.cookie(refreshTokenCookieName, token.refresh_token, {
			httpOnly: true
		});
	}

};