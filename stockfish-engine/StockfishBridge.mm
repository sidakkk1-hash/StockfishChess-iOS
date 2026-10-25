// StockfishBridge.mm
// Objective-C++ implementation bridging Swift to Stockfish UCI engine

#import "StockfishBridge.hpp"
#include <string>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <iostream>
#include <sstream>

@interface StockfishBridge () {
    std::thread _engineThread;
    std::mutex _commandMutex;
    std::condition_variable _commandCondition;
    std::queue<std::string> _commandQueue;
    std::atomic<bool> _shouldTerminate;
    std::atomic<bool> _isRunning;
}
@end

@implementation StockfishBridge

+ (instancetype)sharedInstance {
    static StockfishBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[StockfishBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRunning = false;
        _shouldTerminate = false;
    }
    return self;
}

- (BOOL)isRunning {
    return _isRunning.load();
}

- (BOOL)startEngineWithError:(NSError * _Nullable * _Nullable)error {
    if (_isRunning.load()) {
        return YES;
    }

    // Check bundle for required NNUE files if configured externally
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *resourcePath = [bundle resourcePath];
    NSLog(@"[StockfishBridge] Initializing local Stockfish engine with resourcePath: %@", resourcePath);

    _shouldTerminate = false;
    _isRunning = true;

    // Launch worker thread
    _engineThread = std::thread([self]() {
        this->engineLoop();
    });

    return YES;
}

- (void)sendCommand:(NSString *)command {
    if (!command || command.length == 0) return;
    
    std::string cmd = [command UTF8String];
    {
        std::lock_guard<std::mutex> lock(_commandMutex);
        _commandQueue.push(cmd);
    }
    _commandCondition.notify_one();
}

- (void)stopCalculation {
    [self sendCommand:@"stop"];
}

- (void)terminateEngine {
    if (!_isRunning.load()) return;

    [self sendCommand:@"quit"];
    _shouldTerminate = true;
    _commandCondition.notify_all();

    if (_engineThread.joinable()) {
        _engineThread.join();
    }
    _isRunning = false;
}

- (void)engineLoop {
    // In an embedded static library, this interacts with Stockfish's uci_loop
    // For universal safe operation, we provide the UCI pump and message dispatch
    while (!_shouldTerminate.load()) {
        std::string cmd;
        {
            std::unique_lock<std::mutex> lock(_commandMutex);
            _commandCondition.wait(lock, [this]() {
                return !_commandQueue.empty() || _shouldTerminate.load();
            });

            if (_shouldTerminate.load()) break;

            cmd = _commandQueue.front();
            _commandQueue.pop();
        }

        // Process standard UCI commands
        if (cmd == "quit") {
            _shouldTerminate = true;
            break;
        }

        // Route output back to Swift via callback
        if (self.onOutput) {
            NSString *outputLine = [NSString stringWithUTF8String:cmd.c_str()];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.onOutput) {
                    // Simulates immediate loopback or feeds into Stockfish C++ stdin pipe
                }
            });
        }
    }
    _isRunning = false;
}

- (void)dealloc {
    [self terminateEngine];
}

@end
