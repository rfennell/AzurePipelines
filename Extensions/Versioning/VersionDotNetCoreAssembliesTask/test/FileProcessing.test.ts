import "jest";

import { findFiles,
  ProcessFile,
  extractVersion,
  SplitArrayOfNames
} from "../src/AppyVersionToAssembliesFunctions";

import * as fs from "fs";
import * as fse from "fs-extra";
import * as  copyFileSync from "fs-copy-file-sync";

describe("Test the basic file processing", () => {
    beforeEach(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/core.csproj.initial", "test/testdata/core.csproj");
      copyFileSync("test/testdata/coreUTF8.csproj.initial", "test/testdata/coreUTF8.csproj");
    });

    it("should be able to update a AssemblyVersion in a file", () => {
      var file = "test/testdata/core.csproj";
      var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
      ProcessFile(file, "AssemblyVersion", "9.9.9.9", fieldArray);

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
    });

    it("should be able to update a AssemblyVersion in a UTF8 file", () => {
      var file = "test/testdata/coreUTF8.csproj";
      var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
      ProcessFile(file, "AssemblyVersion", "9.9.9.9", fieldArray);

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`${file}.expected`);

      expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
    });

    afterEach(function() {
      // remove the file if created
      fse.removeSync("test/testdata/*.csproj");
    });

  });

  describe("Test the add field file processing", () => {
    beforeEach(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/coremissing.csproj.initial", "test/testdata/core.csproj");
    });

    it("should be able to add a AssemblyVersion in a file", () => {
      var file = "test/testdata/core.csproj";
      var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
      ProcessFile(file, "AssemblyVersion", "9.9.9.9", fieldArray);

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`test/testdata/coremissing.csproj.expected`);

      expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
    });

    afterEach(function() {
      // remove the file if created
      fse.removeSync("test/testdata/*.csproj");
    });

  });

  describe("Test the generic field file processing", () => {
    beforeEach(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/coremultiple.csproj.initial", "test/testdata/core.csproj");
    });

    it("should be able to update all version fields in a file", () => {
      var file = "test/testdata/core.csproj";
      var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
      ProcessFile(file, "", "9.9.9.9", fieldArray);

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`test/testdata/coremultiple.csproj.expected`);

      expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
    });

    afterEach(function() {
      // remove the file if created
      fse.removeSync("test/testdata/*.csproj");
    });

  });

  describe("Test the empty field file processing", () => {
    beforeEach(function() {
      // make a copy we can overwrite without breaking test data
      copyFileSync("test/testdata/coremissing.csproj.initial", "test/testdata/core.csproj");
    });

    it("should be able to add a detail version field in a file", () => {
      var file = "test/testdata/core.csproj";
      var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
      ProcessFile(file, "", "9.9.9.9", fieldArray, true);

      var editedfilecontent = fs.readFileSync(file);
      var expectedfilecontent = fs.readFileSync(`test/testdata/coremissingaddversion.csproj.expected`);

      expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
    });

    afterEach(function() {
      // remove the file if created
      fse.removeSync("test/testdata/*.csproj");
    });

  });

describe("Test the version extraction", () => {

  it("should be able to extract just a version for a build number", () => {
    var actual = extractVersion(false, "\\d+\\.\\d+\\.\\d+", "ABC-1.2.3.4-XYZ");
    expect(actual).toBe("1.2.3");
  });

  it("should be able to skip extracting a version for a build number", () => {
    var actual = extractVersion(true, "\\d+\\.\\d+\\.\\d+", "ABC-1.2.3.4-XYZ");
    expect(actual).toBe("ABC-1.2.3.4-XYZ");
  });

});

describe("Test the 483 file processing", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core483.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to add a detail version field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "Version", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core483.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});

describe("Test the 494 file processing for singe field", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core494.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to edit AssemblyVersion field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "AssemblyVersion", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core494.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});

describe("Test the 494 file processing for all fields", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core494.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to edit all version field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core494.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});

describe("Test the 549 add missing propertygroup", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core549.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to edit all version field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core549.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});

describe("Test the 551 add missing propertygroup", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core551.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to edit all version field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core551.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});

describe("Test the 346 directory.build.props", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/directory.build.props.initial", "test/testdata/directory.build.props");
  });

  it("should be able to edit all version field in a file", () => {
    var file = "test/testdata/directory.build.props";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/directory.build.props.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/directory.build.props");
  });

});

describe("Test the 589 add missing propertygroup", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core589.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to edit all version field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core589.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});

describe("Test the 589 add missing propertygroup", () => {
  beforeEach(function() {
    // make a copy we can overwrite without breaking test data
    copyFileSync("test/testdata/core589.csproj.initial", "test/testdata/core.csproj");
  });

  it("should be able to edit version field in a file", () => {
    var file = "test/testdata/core.csproj";
    var fieldArray = SplitArrayOfNames("Version, VersionPrefix, AssemblyVersion");
    ProcessFile(file, "Version", "9.9.9.9", fieldArray, true);

    var editedfilecontent = fs.readFileSync(file);
    var expectedfilecontent = fs.readFileSync(`test/testdata/core589.csproj.expected`);

    expect(editedfilecontent.toString()).toBe(expectedfilecontent.toString());
  });

  afterEach(function() {
    // remove the file if created
    fse.removeSync("test/testdata/*.csproj");
  });

});