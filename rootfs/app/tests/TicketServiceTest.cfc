component extends="testbox.system.BaseSpec" {

  function run() {

    beforeAll(function() {
      // Seed the in-memory H2 database that Application.cfc declares for Lucee.
      // This must run before any test — the in-memory DB is empty on first request.
      cfhttp(url="http://localhost:8888/seed-db.cfm", method="GET");
    });

    describe("TicketService", function() {

      var svc = new TicketService();

      it("should return all tickets as an array", function() {
        var result = svc.getAll();
        expect(result).toBeArray();
        expect(arrayLen(result)).toBeGTE(1);
      });

      it("should return a single ticket by id", function() {
        var ticket = svc.getById(1);
        expect(ticket).toBeStruct();
        expect(ticket).toHaveKey("title");
      });

    });

  }
}
