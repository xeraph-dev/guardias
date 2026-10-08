migrations register 1 {
    db eval {
        DROP TABLE IF EXISTS migrations;
    }
}
