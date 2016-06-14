App.controller('HomeController', ['$scope', '$cookies', '$state', function($scope, $cookies, $state) {
	console.log('HomeController');
	if ($cookies.get('accessToken')) {
		console.log('cookie');
		$state.go('documents');
	}
}]);