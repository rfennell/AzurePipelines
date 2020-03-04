import { expect } from "chai";
import { getMode, Mode, getWIModeTags, getCSFilter, Modifier} from "../ReleaseNotesFunctions";
// if you used the '@types/mocha' method to install mocha type definitions, uncomment the following line
import "mocha";

describe("Check the Mode extraction", () => {
    it("should be able to get CS mode when no tags", () => {
      expect(getMode("@@CSLOOP@@")).to.equal(Mode.CS);
    });

    it("should be able to get WI mode when no tags but tag modifier", () => {
      expect(getMode("@@WILOOP[ALL]@@")).to.equal(Mode.WI);
    });

    it("should be able to get BODY mode when no tags", () => {
      expect(getMode("Any other than above two options")).to.equal(Mode.BODY);
    });

    it("should be able to handle lower case tags", () => {
      expect(getMode("@@wiLoop@@")).to.equal(Mode.WI);
    });

    it("should be able to handle lower case tags", () => {
      expect(getMode("@@wiLoop@@")).to.equal(Mode.WI);
    });

    it("should be able to get BODY mode when malformed tag CS", () => {
      expect(getMode("@@CSLOOP")).to.equal(Mode.BODY);
    });

    it("should be able to get BODY mode when malformed tag WI", () => {
      expect(getMode("@@WILOOP")).to.equal(Mode.BODY);
    });

    it("should be able to get WI when there is also a tag", () => {
      expect(getMode("@@WILOOP:TAG1@@")).to.equal(Mode.WI);
    });

    it("should be able to get tag from WI mode", () => {
      var actual = getWIModeTags("@@WILOOP:TAG1@@", ":", "=");
      expect(actual.tags).to.deep.equal(["TAG1"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.All);
    });

    it("should be able to get two tags and the any filter mode", () => {
      var actual = getWIModeTags("@@WILOOP[ANY]:TAG1:TAG2@@", ":", "=");
      expect(actual.tags).to.deep.equal(["TAG1", "TAG2"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.ANY);
    });

    it("should be able to get two tags and the all filter mode", () => {
      var actual = getWIModeTags("@@WILOOP[ALL]:TAG1:TAG2@@", ":", "=");
      expect(actual.tags).to.deep.equal(["TAG1", "TAG2"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.All);
    });

    it("should be able to get two tags and the filter mode when malformed", () => {
      var actual = getWIModeTags("@@WILOOP[Rubbish]:TAG1:TAG2@@", ":", "=");
      expect(actual.tags).to.deep.equal(["TAG1", "TAG2"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.All);
    });

    it("should be able to get two tags and the filter mode when empty", () => {
      var actual = getWIModeTags("@@WILOOP[]:TAG1:TAG2@@", ":", "=");
      expect(actual.tags).to.deep.equal(["TAG1", "TAG2"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.All);
    });

    it("should be able to get two tags inc spaces from WI mode", () => {
      var actual = getWIModeTags("@@WILOOP:TAG 1:TAG 2@@", ":", "=");
      expect(actual.tags).to.deep.equal(["TAG 1", "TAG 2"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.All);
    });

    it("should be able to get empty array if not tags", () => {
        var actual = getWIModeTags("@@WILOOP@@", ":", "=");
        expect(actual.tags).to.deep.equal([]);
        expect(actual.fields).to.deep.equal([]);
        expect(actual.modifier).to.equal(Modifier.All);
    });

    it("should be able to get a tag and a field defintion", () => {
      var actual = getWIModeTags("@@WILOOP[ANY]:System.Title==123:TAG2@@", ":", "==");
      expect(actual.tags).to.deep.equal(["TAG2"]);
      expect(actual.fields).to.deep.equal(["System.Title=123"]);
      expect(actual.modifier).to.equal(Modifier.ANY);
    });

    it("should be able to treat malformed field defintion as a tag", () => {
      var actual = getWIModeTags("@@WILOOP[ANY]:System.Title=AAAA:TAG2@@", ":", "==");
      expect(actual.tags).to.deep.equal(["SYSTEM.TITLE=AAAA", "TAG2"]);
      expect(actual.fields).to.deep.equal([]);
      expect(actual.modifier).to.equal(Modifier.ANY);
    });

});

describe("Check the Regex extraction", () => {

  it("should be able to get regex expression", () => {
    var actual = getCSFilter("@@CSLOOP[^Automated Repo Update #.+]@@");
    expect(actual).equal("^Automated Repo Update #.+");
  });

  it("should be able to get empty regex expression", () => {
    var actual = getCSFilter("@@CSLOOP@@");
    expect(actual).equal("");
  });

  it("should be able to get empty regex expression when malformed", () => {
    var actual = getCSFilter("@@CSLOOP[]@@");
    expect(actual).equal("");
  });
});