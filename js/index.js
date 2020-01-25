// SPDX-License-Identifier: Apache-2.0 OR AGPL-3.0-only
'use strict';
const bulmaToast = require("bulma-toast");
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
		bulmaToast.toast({ message: "コピーしました！", type: "is-success", position: "top-right"});
	},() => {
		bulmaToast.toast({ message: "コピーに失敗しました", type: "is-danger", position: "top-right"});
	})
})

app.ports.sendShareOverWebShareAPIRequest.subscribe((threeWordAddress) => {
	navigator.share({
		title: "w3w-encounter",
		text: `わたしはいまここにいます: ${threeWordAddress}`,
		url: `https://w3w.co/${threeWordAddress}`
	})
	.then(() => {
		bulmaToast.toast({ message: "位置情報の共有に成功しました！", type: "is-success", position: "top-right"});
	})
	.catch((error) => {
		cbulmaToast.toast({ message: "位置情報の共有に失敗しました", type: "is-danger", position: "top-right"});
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