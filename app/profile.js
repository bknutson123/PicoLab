angular.module('profile', [])
    .directive('focusInput', function ($timeout) {
        return {
            link: function (scope, element, attrs) {
                element.bind('click', function () {
                    $timeout(function () {
                        element.parent().find('input')[0].focus();
                    });
                });
            }
        };
    })
    .controller('profilectlr', [
        '$scope', '$http', '$window',
        function ($scope, $http, $window) {
            $scope.eci = "USGMjpeePnTGa2aPDtAcJJ";
            $scope.profile = {};
            $scope.newValsform = [];
            $scope.name = "";
            $scope.location = "";
            $scope.phone_number = "";
            $scope.threshold_temp = "";

            let profileUrl = 'http://localhost:8080/sky/cloud/' + $scope.eci + '/sensor_profile/profile';
            let setValuesUrl = 'http://localhost:8080/sky/event/' + $scope.eci + '/sensor_profile/sensor/profile_updated';

            $scope.load = function () {
                console.log("calling profile url: " + profileUrl);
                $http.get(profileUrl).success(function (data) {
                    console.log("got profile data");
                    console.log(data);
                    angular.copy(data, $scope.profile);
                });
            };

            $scope.setNewValues = function (propertyName) {
                console.log("setting new values: " + $scope.newValsform);
                let data = {};
                if ($scope.location !== "") data = angular.extend({'location': $scope.location}, data);
                if ($scope.name !== "") data = angular.extend({'name': $scope.name}, data);
                if ($scope.phone_number !== "") data = angular.extend({'phone_number': $scope.phone_number}, data);
                if ($scope.threshold_temp !== "") data = angular.extend({'threshold_temperature': $scope.threshold_temp}, data);

                console.log(data);
                $http.post(setValuesUrl, data).success(function (data) {
                    console.log("successfully set values");
                    $scope.location = '';
                    $scope.name = '';
                    $scope.phone_number = '';
                    $scope.threshold_temp = '';
                    $scope.load();
                });
            };
        }
    ]);