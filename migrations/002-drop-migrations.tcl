migrations register 2 {
    db eval {
        DROP TABLE IF EXISTS migrations;
    }
}
