# Enceladus

Enceladus is a Swift-based framework designed to stream cached and network results with a simple API.

## Features

- Local caching using [SwiftData](https://developer.apple.com/xcode/swiftdata/).
- Built-in polling. As long as a stream is active for a given query/ model, it is fetched and emitted at the interval specified by each model  
- Stream models by unique identifier or as a singleton
- Stream lists of models based on query and sort descriptors. Queries are transformed into `SwiftData` predicates.
- Fetch models asynchronously using `async/await`.

## Installation

### Swift Package Manager

To integrate Enceladus into your Xcode project using Swift Package Manager, add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/lekom/Enceladus.git", from: "1.0.0")
]
```

## Usage

### Protocol Definition

Enceladus provides the `ModelProviding` protocol that outlines the methods for fetching models.

```swift
import Combine
import Foundation

public protocol ModelProviding {

    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamModel<T: SingletonModel>(modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?, sortDescriptors: [SortDescriptor<T>]?) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamModels<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?, limit: Int?, sortDescriptors: [SortDescriptor<T>]?) -> AnyPublisher<ListQueryResult<T>, Never>

    func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error>
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, Error>
    func getFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?, sortDescriptors: [SortDescriptor<T>]?) async -> Result<T, Error>
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?, limit: Int?, sortDescriptors: [SortDescriptor<T>]?) async -> Result<[T], Error>

    func configure(headersProvider: (() -> [String: String])?)
}
```

### Accessing the Model Provider

You can access the model provider using the `getModelProvider()` function. This function returns an instance that conforms to the `ModelProviding` protocol.

```swift
let modelProvider = getModelProvider()
```

### Providing Headers for Network Requests

Call `getModelProvider().configure(headersProvider...` once at app launch to ensure any required headers are sent with each network request.  The provided `headersProvider` closure is called on each network request and the returned headers are not cached by this lib between network requests.

```swift
getModelProvider().configure(headersProvider: { ["authorization": "abc"] })
```

### Unit Testing

For unit testing, you can override the default model provider returned from `getModelProvider()` by setting a global variable `mockedModelProvider`.  Set it to any mock instance that adopts the `ModelProviding` protocol.  `MockModelProvider` is provided for convenience in the `EnceladusMocks` target for use in testing.

```swift
var mockedModelProvider: ModelProviding?

func getModelProvider() -> ModelProviding {
    return mockedModelProvider ?? DefaultModelProvider()
}
```

### Example Usage

#### Streaming a Model by ID

```swift
modelProvider.streamModel(MyModel.self, id: "123")
    .sink { result in
        switch result {
        case .loading:
            print("model is being fetched from the network")
        case .loaded(let model)
            print("Model: \(model) found as either a freshly cached item or result of a network request")
        case .error(let error):
            print("Error: \(error) occured while fetching the model")
        }
    }
    .store(in: &cancellables)
```

#### Fetching a Model Asynchronously

```swift
let result = await modelProvider.getModel(MyModel.self, id: "123")
switch result {
case .success(let model):
    print("Model: \(model)")
case .failure(let error):
    print("Error: \(error)")
}
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
