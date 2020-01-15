'use strict';

const { Elm } = require("../src/Main.elm");

const app = Elm.Main.init({
    node: document.getElementById("elm"),
    flags: {
		apiKey: process.env.ELM_W3W_API_KEY,
		supportGeolocation: typeof(navigator.geolocation) === "object" ? true : false,
		supportWebShareAPI: typeof(navigator.share) === "object" ? true : false,
		supportClipboard: typeof(navigator.clipboard) === "object" ? true : false
	}
});

app.ports.sendCopyToClipboardRequest.subscribe((threeWordAddress) => {
	navigator.clipboard.writeText(threeWordAddress).then(() => {
		console.log("copyed!")
	},() => {
		console.log("copy failed!")
	})
})

app.ports.sendShareOverWebShareAPIRequest.subscribe((threeWordAddress) => {
	navigator.share({
		title: "w3w-encounter",
		text: `わたしはいまここにいます: ${threeWordAddress}`,
		url: `https://w3w.co/${threeWordAddress}`
	})
	.then(() => {
		console.log("Web Share API success!")
	})
	.catch((error) => {
		console.log("Web Share API failed: ", error)
	})
})

navigator.geolocation.watchPosition(
	function(position) {
		console.log(position);
		const data = {
			location: {
				lat: position.coords.latitude,
				lng: position.coords.longitude
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