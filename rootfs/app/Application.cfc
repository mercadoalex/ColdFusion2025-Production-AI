component {
  this.name = "cfTrainingApp";

  this.datasources["training_db"] = {
    class:            "org.h2.Driver",
    connectionString: "jdbc:h2:mem:training_db;DB_CLOSE_DELAY=-1;DATABASE_TO_UPPER=FALSE",
    username:         "sa",
    password:         ""
  };
}
