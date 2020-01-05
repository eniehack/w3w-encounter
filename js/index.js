'use strict';

const { Elm } = require("../src/Main.elm");

const app = Elm.Main.init({
    node: document.getElementById("elm"),
    flags: {
		apiKey: process.env.ELM_W3W_API_KEY,
		supportGeolocation: navigator.geolocation ? true : false,
	}
});

navigator.geolocation.watchPosition(
	function(position) {
		console.log(position);
		const data = {
			location: {
				latitude: position.coords.latitude,
				longitude: position.coords.longitude
			},
			errorCode: null
		}
		console.log(data)
		app.ports.receiveLocation.send(data);
	},
	function(error) {
		console.log(error);
		app.ports.receiveLocation.send({
			location: null,
			errorCode: error.code
		});
	}
);