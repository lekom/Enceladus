# Enceladus

Enceladus is a Swift-based framework designed to stream cached and network results of a `BaseModel` or `ListModel`, facilitating efficient data retrieval and management by leveraging both local caching mechanisms and network requests.

## Features

- Stream models by unique identifier.
- Stream singleton models.
- Stream the first matching model from a list based on query and sort descriptors.
- Stream lists of models from the cache or remotely.
- Fetch models asynchronously using `async/await`.

## Installation

### Swift Package Manager

To integrate Enceladus into your Xcode project using Swift Package Manager, add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Enceladus.git", from: "1.0.0")
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
}
```

### Accessing the Model Provider

You can access the model provider using the `getModelProvider()` function. This function returns an instance of a class or struct that conforms to the `ModelProviding` protocol.

```swift
let modelProvider = getModelProvider()
```

### Unit Testing

For unit testing, you can override the `getModelProvider()` function by setting a global variable `mockedModelProvider` to any class or struct that adopts the `ModelProviding` protocol.

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

## License

Enceladus is released under the MIT license. See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.
