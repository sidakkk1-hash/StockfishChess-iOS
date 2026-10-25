// StockfishBridge.hpp
// Clean C++ / Objective-C++ interface for Stockfish UCI communication on iOS

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^StockfishOutputBlock)(NSString *line);
typedef void (^StockfishErrorBlock)(NSString *errorMessage);

@interface StockfishBridge : NSObject

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic, copy, nullable) StockfishOutputBlock onOutput;
@property (nonatomic, copy, nullable) StockfishErrorBlock onError;

+ (instancetype)sharedInstance;

/// Initializes and starts the background Stockfish thread.
/// Returns YES if engine started successfully, NO if an error occurred.
- (BOOL)startEngine;

/// Sends a raw UCI command (e.g., "uci", "isready", "position fen ...", "go depth 15")
- (void)sendCommand:(NSString *)command;

/// Sends "stop" to interrupt ongoing calculation immediately
- (void)stopCalculation;

/// Gracefully shuts down the background engine thread
- (void)terminateEngine;

@end

NS_ASSUME_NONNULL_END
