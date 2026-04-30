<?php
require 'backend/vendor/autoload.php';
$app = require 'backend/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();
config(['database.default' => 'sqlite', 'database.connections.sqlite.url' => 'postgresql://user:pass@host:5432/dbname']);
try {
    $conn = app('db')->connection();
    var_dump($conn->getConfig());
} catch (\Throwable $e) {
    echo "Error: " . $e->getMessage() . "\n";
}