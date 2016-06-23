var App = angular.module('app', [
	'ui.router',
	'ui.bootstrap',
	'ngCookies',
	'selectize'
]);


App.config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
	$stateProvider
		.state('/', {
			url: '/',
			templateUrl: 'templates/home.html',
			controller: 'HomeController'
		})
		.state('about', {
			url: '/about',
			templateUrl: 'templates/about.html'
		});
	$urlRouterProvider.otherwise('/');
}]);