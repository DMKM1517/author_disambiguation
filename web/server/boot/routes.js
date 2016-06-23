module.exports = function(app) {
	'use strict';

	const fs = require('fs');
	var config = JSON.parse(fs.readFileSync(__dirname + '/../../config.json'));
	var oauth2 = require('simple-oauth2')({
		site: 'https://api.mendeley.com',
		clientID: config.clientId,
		clientSecret: config.clientSecret
	});

	// var cookieParser = require('cookie-parser');
	var accessTokenCookieName = 'accessToken';
	var refreshTokenCookieName = 'refreshToken';
	var oauthPath = '/oauth';
	// var examplesPath = '/examples';
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

	app.get('/getSubjects', function(req, res) {
		let query = `select distinct subject
			from source.subjects
			order by subject;`;
		app.dataSources.ArticlesDB.connector.execute(query, function(err, results) {
			res.json(results);
		});
	})

	function setCookies(res, token) {
		res.cookie(accessTokenCookieName, token.access_token, {
			maxAge: token.expires_in * 1000 * 12
		});
		// res.cookie(refreshTokenCookieName, token.refresh_token, {
		// 	httpOnly: true
		// });
	}

};