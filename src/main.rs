use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
mod routes;
use routes::signals;

#[get("/_health")]
async fn health() -> impl Responder {
    HttpResponse::Ok().body("OK")
}

#[get("/")]
async fn index() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(r#"
            <!DOCTYPE html>
<html>
<head>
    <title>Trading Signals Backend</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .endpoint { 
            background: #f8f9fa; 
            padding: 12px 15px; 
            margin: 8px 0; 
            border-radius: 5px; 
            border-left: 4px solid #3498db;
        }
        .method { 
            display: inline-block; 
            width: 70px; 
            padding: 3px 8px; 
            margin-right: 10px; 
            border-radius: 3px; 
            text-align: center; 
            font-weight: bold; 
            font-size: 0.9em; 
        }
        .get { background: #d4edda; color: #155724; }
        .post { background: #d1ecf1; color: #0c5460; }
        a { color: #2980b9; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .container { max-width: 800px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Trading Signals Backend</h1>
        <p>✅ Server is running on Railway!</p>
        <p>📊 <strong>Live Prices from CoinGecko:</strong> BTC, ETH, SOL, PAXG</p>
        
        <h3>🌐 Available Endpoints:</h3>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/_health">/_health</a> - Simple health check
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/health">/health</a> - Detailed health with endpoints
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/prices">/prices</a> - <strong>LIVE</strong> crypto prices from CoinGecko
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/signals">/signals</a> - Trading signals based on live prices
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/explain-signal">/explain-signal</a> - AI explains trading signals
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/explain-all-signals">/explain-all-signals</a> - AI explains all signals
        </div>
        <div class="endpoint">
            <span class="method post">POST</span> 
            /tradingview-webhook - Receive TradingView alerts
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/tradingview-alerts">/tradingview-alerts</a> - Recent alerts
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/alerts/BTC">/alerts/{symbol}</a> - Alerts for specific symbol
        </div>
        <div class="endpoint">
            <span class="method get">GET</span> 
            <a href="/cache-stats">/cache-stats</a> - Cache statistics
        </div>
        <div class="endpoint">
            <span class="method post">POST</span> 
            /clear-alerts - Clear all alerts
        </div>
        <div class="endpoint">
            <span class="method post">POST</span> 
            /clear-cache - Clear price cache
        </div>
        
        <h3>🔧 Testing:</h3>
        <p>Test with curl:</p>
        <pre><code>curl http://localhost:8080/explain-signal
curl http://localhost:8080/explain-signal?symbol=SOL
curl http://localhost:8080/explain-all-signals</code></pre>
    </div>
</body>
</html>
        "#)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("PORT must be a number");
    
    println!("🚀 Trading Signals Backend starting on port {}", port);
    println!("📊 Fetching LIVE prices from CoinGecko API");
    println!("✅ Supported coins: BTC, ETH, SOL, PAXG");
    println!("🤖 AI Explanations available at /explain-signal");
    
    HttpServer::new(|| {
        App::new()
            .service(health)
            .service(index)
            .service(signals::health_check)
            .service(signals::get_prices)
            .service(signals::get_signals)
            .service(signals::get_tradingview_alerts)
            .service(signals::get_symbol_alerts)
            .service(signals::get_cache_stats)
            .route("/explain-signal", web::get().to(signals::explain_signal))
            .route("/explain-all-signals", web::get().to(signals::explain_all_signals))
            .route("/tradingview-webhook", web::post().to(signals::tradingview_webhook))
            .route("/clear-alerts", web::post().to(signals::clear_alerts))
            .route("/clear-cache", web::post().to(signals::clear_cache))
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}
