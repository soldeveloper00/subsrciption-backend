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
                    <pre><code>curl https://subsrciption-backend-production.up.railway.app/prices
curl https://subsrciption-backend-production.up.railway.app/signals</code></pre>
                </div>
            </body>
            </html>
        "#)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Get port from Railway environment or default to 8080
    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("PORT must be a number");
    
    let bind_address = format!("0.0.0.0:{}", port);
    
    println!("🚀 Trading Signals Backend starting on {}", bind_address);
    println!("📊 Fetching LIVE prices from CoinGecko API");
    println!("✅ Supported coins: BTC, ETH, SOL, PAXG");
    println!("📡 Health check available at: http://0.0.0.0:{}/_health", port);
    
    // Configure and start the server
    HttpServer::new(|| {
        App::new()
            .service(health)
            .service(index)
            .route("/health", web::get().to(signals::health_check))
            .route("/prices", web::get().to(signals::get_prices))
            .route("/signals", web::get().to(signals::get_signals))
            .route("/tradingview-webhook", web::post().to(signals::tradingview_webhook))
            .route("/tradingview-alerts", web::get().to(signals::get_tradingview_alerts))
            .route("/alerts/{symbol}", web::get().to(signals::get_symbol_alerts))
            .route("/cache-stats", web::get().to(signals::get_cache_stats))
            .route("/clear-alerts", web::post().to(signals::clear_alerts))
            .route("/clear-cache", web::post().to(signals::clear_cache))
    })
    .bind(&bind_address)
    .expect(&format!("Failed to bind to {}", bind_address))
    .workers(2) // Reduce workers for Railway's memory limits
    .run()
    .await
}