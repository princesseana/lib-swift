# Swift library for Pryv.io

This Swift library is meant to facilitate writing iOS apps for a Pryv.io platform, it follows the [Pryv.io App Guidelines](https://api.pryv.com/guides/app-guidelines/).

[![CI Status](https://img.shields.io/travis/alemannosara/PryvApiSwiftKit.svg?style=flat)](https://travis-ci.org/alemannosara/PryvApiSwiftKit)
[![Version](https://img.shields.io/cocoapods/v/PryvApiSwiftKit.svg?style=flat)](https://cocoapods.org/pods/PryvApiSwiftKit)
[![License](https://img.shields.io/cocoapods/l/PryvApiSwiftKit.svg?style=flat)](https://cocoapods.org/pods/PryvApiSwiftKit)
[![Platform](https://img.shields.io/cocoapods/p/PryvApiSwiftKit.svg?style=flat)](https://cocoapods.org/pods/PryvApiSwiftKit)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

iOS 10.0 is required to use this library.

## Usage
  
### Table of Contents
  
- [Import](#import)
- [Obtaining a Connection](#obtaining-a-connection)
  - [Using an API endpoint](#using-an-api-endpoint)
  - [Using a Username & Token (knowing the service information URL)](#using-a-username--token-knowing-the-service-information-url)
  - [Within a WebView](#within-a-webview)
  - [Using Service.login() *(trusted apps only)*](#using-servicelogin-trusted-apps-only)
- [API calls](#api-calls)
- [Advanced usage of API calls with optional individual result](#advanced-usage-of-api-calls-with-optional-individual-result)
- [Get Events Streamed](#get-events-streamed)
  - [Example:](#example-1)
  - [result:](#result)
  - [Example with Includes deletion:](#example-with-includes-deletion)
  - [result:](#result-1)
- [Events with Attachments](#events-with-attachments)
- [High Frequency Events](#high-frequency-events)
- [Service Information](#service-information)
  - [Pryv.Service](#pryvservice)
    - [Initizalization with a service info URL](#initizalization-with-a-service-info-url)
    - [Initialization with the content of a service info configuration](#initialization-with-the-content-of-a-service-info-configuration)
    - [Usage of Pryv.Service.](#usage-of-pryvservice)
  
### Import

PryvApiSwiftKit is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'PryvApiSwiftKit'
```

### Obtaining a Connection

A connection is an authenticated link to a Pryv.io account.

#### Using an API endpoint

The format of the API endpoint can be found in your platform's [service information](https://api.pryv.com/reference/#service-info) under the `api` property. The most frequent one has the following format: `https://{token}@{api-endpoint}`

```swift
let apiEndpoint = "https://ck6bwmcar00041ep87c8ujf90@drtom.pryv.me"
let connection = Connection(apiEndpoint: apiEndpoint)
```

#### Using a Username & Token (knowing the service information URL)

```swift
let service = Service(pryvServiceInfoUrl: "https://reg.pryv.me/service/info")
service.apiEndpointFor(username: username, token: token).then { apiEndpoint in
    let connection = Connection(apiEndpoint: apiEndpoint)
}
```

#### Within a WebView

The following code is an implementation of the [Pryv.io Authentication process](https://api.pryv.com/reference/#authenticate-your-app). 

```swift
{
    let service = Service(pryvServiceInfoUrl: "https://reg.pryv.me/service/info")
    let authPayload: Json = [ // See: https://api.pryv.com/reference/#auth-request
        "requestingAppId": "lib-swift-test",
        "requestedPermissions": [
            [
                "streamId": "test",
                "level": "manage"
            ]
        ],
        "languageCode": "fr" // optional (default english)
    ]

    service.setUpAuth(authSettings: authPayload, stateChangedCallback: stateChangedCallback).then { authUrl in
        // open a webview with URL(string: authUrl)!
    }
}

// event Listener for Authentication steps, called each time the authentication state changed
func stateChangedCallback(authResult: AuthResult) {
    switch authResult.state {
    case .need_signin: // do nothing if still needs to sign in
        return
        
    case .accepted: 
        // close webview
        let connection = Connection(apiEndpoint: authResult.apiEndpoint)
        print("Successfully authenticated: \(connection.getApiEndpoint())")
        
    case .refused: 
        // close webview
        
    case .timeout: 
        // close webview
        print("Authentication timed out")
    }
}
```
  
#### Using Service.login() *(trusted apps only)*

[auth.login reference](https://api.pryv.com/reference-full/#login-user)

```swift
import Promises

let pryvServiceInfoUrl = "https://reg.pryv.me/service/info"
let appId = "lib-swift-sample"
let service = Service(pryvServiceInfoUrl: "https://reg.pryv.me/service/info")
service.login(username: username, password: password, appId: appId).then { connection in 
    // handle connection object
}
```

### API calls

Api calls are based on the `batch` call specifications: [Call batch API reference](https://api.pryv.com/reference/#call-batch)

```swift
let apiCalls: [APICall] = [
  [
    "method": "streams.create",
    "params": [
        "id": "heart", 
        "name": "Heart"
    ]
  ],
  [
    "method": "events.create",
    "params": [
        "time": 1385046854.282, 
        "streamId": "heart", 
        "type": "frequency/bpm", 
        "content": 90 
    ]
  ],
  [
    "method": "events.create",
    "params": [
        "time": 1385046854.283, 
        "streamId": "heart", 
        "type": "frequency/bpm", 
        "content": 120 
    ]
  ]
]

connection.api(APICalls: apiCalls).then { result in 
    // handle the result
}
```

### Advanced usage of API calls with optional individual result

```swift
var count = 0
// the following will be called on each API method result it was provided for
let handleResult: (Event) -> () = { result in 
    print("Got result \(count): \(String(describing: result))")
    count += 1
}

let apiCalls: [APICall] = [
  [
    "method": streams.create,
    "params": [
        "id": "heart", 
        "name": "Heart" 
    ]
  ],
  [
    "method": "events.create",
    "params": [
        "time": 1385046854.282, 
        "streamId": "heart", 
        "type": "frequency/bpm", 
        "content": 90 
    ]
  ],
  [
    "method": "events.create",
    "params": [
        "time": 1385046854.283, 
        "streamId": "heart",
        "type": "frequency/bpm",
        "content": 120 
    ]
  ]
]

let handleResults: [Int: (Event) -> ()] = [
    1: handleResult, 
    2: handleResult
]

connection.api(APICalls: apiCalls, handleResults: handleResults).catch { error in 
    // handle error
}
```

### Get Events Streamed

When `events.get` will provide a large result set, it is recommended to use a method that streams the result instead of the batch API call.

`Connection.getEventsStreamed()` parses the response JSON as soon as data is available and calls the `forEachEvent()` callback on each event object.

The callback is meant to store the events data, as the function does not return the API call result, which could overflow memory in case of JSON deserialization of a very large data set.
Instead, the function returns an events count and eventually event deletions count as well as the [common metadata](https://api.pryv.com/reference/#common-metadata).

#### Example:

``````  swift
let now = Date().timeIntervalSince1970
let queryParams: Json = ["fromTime": 0, "toTime": now, "limit": 10000]
var events = [Event]()
let forEachEvent: (Event) -> () = { event in 
    events.append(event)
}

connection.getEventsStreamed(queryParams: queryParams, forEachEvent: forEachEvent).then { result in 
    // handle the result 
}
``````

#### result:

```swift
[
  "eventsCount": 10000,
  "meta": [
      "apiVersion": "1.4.26",
      "serverTime": 1580728336.864,
      "serial": 2019061301
  ]
]
```

#### Example with Includes deletion:

``````  swift
let now = Date().timeIntervalSince1970
let queryParams: Json = ["fromTime": 0, "toTime": now, "includeDeletions": true, "modifiedSince": 0]
const events = []
var events = [Event]()
let forEachEvent: (Event) -> () = { event in 
    events.append(event)
    // events with .deleted or/and .trashed properties can be tracked here
}

connection.getEventsStreamed(queryParams: queryParams, forEachEvent: forEachEvent).then { result in 
    // handle the result 
}
``````

#### result:

```swift
[  
  "eventDeletionsCount": 150,
  "eventsCount": 10000,
  meta: [
      "apiVersion": "1.4.26",
      "serverTime": 1580728336.864,
      "serial": 2019061301
  ]
]
```

### Events with Attachments

This shortcut allows to create an event with an attachment in a single API call.

```swift
let payload: Event = ["streamId": "data", "type": "picture/attached"]
let filePath = "./test/my_image.png"
let mimeType = "image/png"

connection?.createEventWithFile(event: payload, filePath: filePath, mimeType: "application/pdf").then { result in 
    // handle the result
}
```
  
### High Frequency Events 

Reference: [https://api.pryv.com/reference/#hf-events](https://api.pryv.com/reference/#hf-events)

```swift
func generateSerie() -> [[Int, CGFloat]] {
  var serie = [(Int, CGFloat)]()
  for t in 0..< 100000 { // t will be the deltatime in seconds
    serie.append([t, sin(Double(t)/1000.0)])
  }
  return serie
}

let pointsA = generateSerie()
let pointsB = generateSerie()

func postHFData(points: [(Int, CGFloat)]) { // must return a Promise
    let internalFunction: (Event) -> () = { event in // will be called each time an HF event is created
        let eventId = event["id"] as! String
        connection.addPointsToHFEvent(eventId, ["deltaTime", "value"], points)
    }
    return internalFunction
}

let apiCalls: [APICall] = [
  [
    "method": "streams.create",
    "params": [
        "id": "signal1", 
        "name": "Signal1"
    ]
  ],
  [
    "method": "streams.create",
    "params": [
        "id": "signal2", 
        "name": "Signal2"
    ]
  ],
  [
    "method": "events.create",
    "params": [
        "streamId": "signal1", 
        "type": "serie:frequency/bpm" 
    ]
  ],
  [
    "method": "events.create",
    "params": [
        "streamId": "signal2", 
        "type": "serie:frequency/bpm"
    ]
  ]
]

let handleResults: [Int: (Event) -> ()] = [
    2: postHFData(pointsA), 
    3: postHFData(pointsB)
]

connection.api(APICalls: apiCalls, handleResults: handleResults).catch { error in 
    // handle error
}

```
  
### Service Information

A Pryv.io deployment is a unique "Service", as an example **Pryv Lab** is a service, deployed on the **pryv.me** domain name.

It relies on the content of a **service information** configuration, See: [Service Information API reference](https://api.pryv.com/reference/#service-info)

#### Pryv.Service 

Exposes tools to interact with Pryv.io at a "Platform" level. 

##### Initizalization with a service info URL

```swift
let service = Service(pryvServiceInfoUrl: "https://reg.pryv.me/service/info")
```

##### Initialization with the content of a service info configuration

Service information properties can be overriden with specific values. This might be useful to test new designs on production platforms.

```swift
let serviceInfoUrl = "https://reg.pryv.me/service/info"
let serviceCustomizations: Json = [
  "name": "Pryv Lab 2"
]
let service = Service(pryvServiceInfoUrl: serviceInfoUrl, serviceCustomization: serviceCustomizations)
```

##### Usage of Pryv.Service.

See: [Pryv.Service](https://pryv.github.io/js-lib/docs/Pryv.Service.html) for more details

- `service.info()` - returns the content of the serviceInfo in a Promise 

  ```swift
  // example: get the name of the platform
  service.info().then { serviceInfo in 
    let serviceName = serviceInfo.name
  }
  ```
  
- `service.infoSync()`: returns the cached content of the serviceInfo, requires `service.info()` to be called first.

- `service.apiEndpointFor(username, token)` Will return the corresponding API endpoint for the provided credentials, `token` can be omitted.

# Change Log

## 2.0.1 Initial Release 
