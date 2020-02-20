angular.module('timing', [])
    .directive('focusInput', function($timeout) {
        return {
            link: function(scope, element, attrs) {
                element.bind('click', function() {
                    $timeout(function() {
                        element.parent().find('input')[0].focus();
                    });
                });
            }
        };
    })
    .controller('MainCtrl', [
        '$scope','$http','$window',
        function($scope,$http,$window){
            $scope.temperatures = [];
            $scope.thresholds = [];
            $scope.inRangeTemperatures = [];
            $scope.eci = "USGMjpeePnTGa2aPDtAcJJ";
            $scope.current_temp = "";

            let temperaturesUrl = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/temperature_store/temperatures';
            let thresholdsUrl = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/temperature_store/threshold_violations';
            let inRangeUrl = 'http://localhost:8080/sky/cloud/'+$scope.eci+'/temperature_store/inrange_temperatures';
            setInterval(function() {
                    $http.get(temperaturesUrl).success(function(data){
                        console.log("set temperatures");
                        console.log(data);
                        angular.copy(data, $scope.temperatures);
                    });
                    $http.get(thresholdsUrl).success(function(data){
                        console.log("set thresholds");
                        console.log(data);
                        angular.copy(data, $scope.thresholds);
                    });
                    $http.get(inRangeUrl).success(function(data){
                        console.log("set inRangeUrl");
                        console.log(data);
                        angular.copy(data, $scope.inRangeTemperatures);
                    });
                    $scope.current_temp = $scope.temperatures[$scope.temperatures.length-1].temp;
            }, 1000);
        }
    ]);