//
//  AsyncAwaitFuture.swift
//  Enceladus
//
//  Created by Leko Murphy on 11/14/24.
//

import Foundation
import Combine

final class AsyncAwaitFuture<Output, Failure: Error>: Publisher, Sendable {
    public typealias Promise = @Sendable (Result<Output, Failure>) -> Void

    private let work: @Sendable (@escaping Promise) async -> Void

    public init(_ work: @Sendable @escaping (@escaping Promise) async -> Void) {
        self.work = work
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input, S: Sendable {
        let subscription = AsyncAwaitSubscription(subscriber: subscriber, work: work)
        subscriber.receive(subscription: subscription)
    }
}

private extension AsyncAwaitFuture {
    final class AsyncAwaitSubscription<S: Subscriber>: Subscription where S.Input == Output, S.Failure == Failure, S: Sendable {
        private var subscriber: S?
        private let task: Task<Void, Error>
        
        init(subscriber: S, work: @Sendable @escaping (@escaping Promise) async -> Void) {
            self.subscriber = subscriber
            task = Task {
                await work { result in
                    switch result {
                    case .success(let output):
                        _ = subscriber.receive(output)
                        subscriber.receive(completion: .finished)
                    case .failure(let failure):
                        subscriber.receive(completion: .failure(failure))
                    }
                }
            }
        }

        func request(_ demand: Subscribers.Demand) { }

        func cancel() {
            subscriber = nil
            task.cancel()
        }
    }
}
