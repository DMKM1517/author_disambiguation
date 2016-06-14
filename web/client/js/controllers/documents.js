App.controller('DocumentsController', ['$scope', '$http', function($scope, $http) {
	console.log('DocumentsController');
	MendeleySDK.API.setAuthFlow(MendeleySDK.Auth.authCodeFlow({
		apiAuthenticateUrl: '/login',
		// refreshAccessTokenUrl: '/oauth/refresh'
	}));
	MendeleySDK.API.profiles.me().done(function(profile) {
		$scope.name = profile.display_name;
		$scope.$apply();
	});
	MendeleySDK.API.documents.list().done(function(docs) {
		$scope.documents = docs;
		$scope.$apply();
	}).fail(function(request, response) {
		console.log('Failed!');
		console.log('URL:', request.url);
		console.log('Status:', response.status);
	});
}])