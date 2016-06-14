module.exports = function(app) {
	'use strict';

	var config = JSON.parse(require('fs').readFileSync(__dirname + '/../../config.json'));
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
	var redirectUri = 'http://localhost:3000' + tokenExchangePath;

	app.get('/login', function(req, res) {
		res.clearCookie(accessTokenCookieName);
		res.clearCookie(refreshTokenCookieName);
		res.redirect(oauthPath);
	});

	app.get(oauthPath, function(req, res) {
		var authorizationUri = oauth2.authCode.authorizeURL({
			redirect_uri: redirectUri,
			scope: config.scope || 'all'
		});
		res.redirect(authorizationUri);
	});

	app.get(tokenExchangePath, function(req, res, next) {
		console.log('Starting token exchange');
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

	function setCookies(res, token) {
		res.cookie(accessTokenCookieName, token.access_token, {
			maxAge: token.expires_in * 1000 * 5
		});
		// res.cookie(refreshTokenCookieName, token.refresh_token, {
		// 	httpOnly: true
		// });
	}

};