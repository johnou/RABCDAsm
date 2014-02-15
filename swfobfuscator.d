/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is ironically part of RABCDAsm.
 *
 *  RABCDAsm is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  RABCDAsm is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with RABCDAsm.  If not, see <http://www.gnu.org/licenses/>.
 */

module swfobfuscator;

import std.algorithm : find;
import std.conv;
import std.digest.md;
import std.exception;
import std.file;
import std.json;
import std.path;
import std.random;
import std.regex;
import std.stdio;
import std.string;
import std.zip;

import swffile;
import swfobfuscatoroptions;
import tagutils;

import abcfile;
import binfile;
import expfile;
import frmfile;
import impfile;
import pobfile;
import sprfile;
import symfile;

class SwfObfuscator
{
	SwfObfuscatorOptions opt;

	uint[string] globalSymbols;

	bool[string] excludes;
	bool[string] includes;

	string[string] fixedNames;
	string[string] fullRenames;
	string[string] partialRenames;

	uint tagNumber = 0;

	uint[] jsonIds;

	bool sealed = false;

	this(ref SwfObfuscatorOptions o)
	{
		opt = o;

		if (opt.excludesFile)
			initializeExcludes(opt.excludesFile);

		if (opt.includesFile)
			initializeIncludes(opt.includesFile);

		if (opt.fixedNamesFile)
			initializeFixedNames(opt.fixedNamesFile);

		foreach (g; opt.globalFiles)
			initializeGlobalSymbols(g);

		globalSymbols.rehash();

		if (opt.verbose)
			foreach (key, val; globalSymbols)
				writefln("GSY: %s = %d", key, val);
	}

	void initializeGlobalSymbols(string globalFile)
	{
		if (!exists(globalFile))
		{
			const string msg = "The global file does not exist! " ~ globalFile;
			throw new Exception(msg);
		}

		ZipArchive zip = new ZipArchive(read(globalFile));

		scope swf = SWFFile.read(zip.expand(zip.directory["library.swf"]));

		foreach (uint count, ref tag; swf.tags)
		{
			if (opt.verbose)
				writefln("GSY: %d %s %d %s %s", count, tagNames[tag.type], tag.length,
						 tag.forceLongLength ? "true" : "false", toHexString(md5Of(tag.data)));

			ABCFile abc = readTag!(ABCFile)(tag);

			for (uint n = 1; abc && n < abc.strings.length; ++n)
				++globalSymbols[abc.strings[n]];

			SymFile sym = readTag!(SymFile)(tag);

			if (opt.verbose && sym)
			{
				writefln("GSY: sym.symbols.length = %d", sym.symbols.length);
				foreach (symbol; sym.symbols)
					writefln("GSY: idref = %d, name = %s", symbol.idref, symbol.name);
			}
		}
	}

	void initializeExcludes(string excludesFile)
	{
		if (!exists(excludesFile))
			throw new Exception("Excludes file does not exist! " ~ excludesFile);

		foreach (line; File(excludesFile).byLine())
		{
			const string s = strip(to!string(line));

			if (s[0] == '#')
				continue;

			if (s in excludes)
				throw new Exception("Duplicate exclude found! " ~ s);

			excludes[s] = true;

			if (opt.verbose)
				writeln("EXC: " ~ s);
		}

		excludes.rehash();
	}

	void initializeIncludes(string includesFile)
	{
		if (!exists(includesFile))
			throw new Exception("Includes file does not exist! " ~ includesFile);

		foreach (line; File(includesFile).byLine())
		{
			const string s = strip(to!string(line));

			if (s[0] == '#')
				continue;

			if (s in includes)
				throw new Exception("Duplicate include found! " ~ s);

			includes[s] = true;

			if (opt.verbose)
				writeln("INC: " ~ s);
		}

		includes.rehash();
	}

	void initializeFixedNames(string fixedNamesFile)
	{
		if (!exists(fixedNamesFile))
			throw new Exception("Fixed names file does not exist! " ~ fixedNamesFile);

		uint num = 0;

		foreach (line; File(fixedNamesFile).byLine())
		{
			const string s = strip(to!string(line));

			if (s[0] == '#')
				continue;

			++num;

			if (s[0] == '!')
				continue;

			const string f = format("%df%d", num, s.length);

			if (s in fixedNames)
				throw new Exception("Duplicate fixed name found! " ~ s);

			fixedNames[s] = f;

			if (opt.verbose)
				writeln("FIX: " ~ s ~ " " ~ f);
		}

		fixedNames.rehash();
	}

	string reformatName(uint n, uint p)
	{
		return format("%s%dt%ds%d", opt.namePrefix, tagNumber, n, p);
	}

	string renameFull(string s, uint n)
	{
		string rename = s in partialRenames ? partialRenames[s] : reformatName(n, 0);

		fullRenames[s] = rename;

		return rename;
	}

	string renameByParts(string s, uint n)
	{
		string r;
		uint i = 0;

		auto m = match(s, regex(`([^.:]+)([.:]?)`, "g"));

		while (!m.empty)
		{
			string name = m.captures[1];
			string rename;

			if (name in fullRenames)
			{
				rename = fullRenames[name];
			}
			else if (name in partialRenames)
			{
				rename = partialRenames[name];
			}
			else
			{
				rename = reformatName(n, i++); // @TODO: check excludes for partials?
				partialRenames[name] = rename;
			}

			r ~= rename ~ m.captures[2];
			m.popFront();
		}

		enforce(s.length > 0 && r.length > 0, "Invalid rename!");

		fullRenames[s] = r;
		fullRenames[tr(s, [':'], ['.'])] = tr(r, [':'], ['.']);

		return r;
	}

	string renameString(string s, uint n)
	{
		if (s in fullRenames)
			return fullRenames[s];

		if (match(s, regex(`[.:]`)))
			return renameByParts(s, n);

		return renameFull(s, n);
	}

	bool isObfuscatable(ABCFile abc, string name, uint n)
	{
		if (name in includes)
			return true;

		if (name in excludes || name in globalSymbols || isUrl(name))
			return false;

		return abc.isNamespace(n) || abc.isMultiname(n);
	}

	void generateFullRenames(ref SWFFile.Tag tag)
	{
		ABCFile abc = readTag!(ABCFile)(tag);

		if (abc)
		{
			++tagNumber;

			if (opt.verbose)
				writeln("REN: Generating full renames ...");

			for (uint n = 1; n < abc.strings.length; ++n)
			{
				string name = abc.strings[n];

				if (isObfuscatable(abc, name, n))
				{
					string rename = renameString(name, n);

					if (opt.verbose)
						writeln("REN: " ~ name ~ " => " ~ rename);
				}
			}
		}

		SymFile sym = readTag!(SymFile)(tag);

		if (sym)
		{
			foreach (ref symbol; sym.symbols)
				if (find(opt.jsonNames, symbol.name) != [])
				{
					jsonIds ~= symbol.idref;
					if (opt.verbose)
						writefln("REN: json symbol %d %s %s", symbol.idref, symbol.name, jsonIds);
				}
		}
	}

	void processAbcTag(ref SWFFile.Tag tag)
	{
		ABCFile abc = readTag!(ABCFile)(tag);

		if (abc)
		{
			if (opt.verbose)
				writeln("ABC: Processing abc ...");

			if (abc.hasDebugOpcodes && !opt.allowDebug)
			{
				const string msg = "Debug opcodes found! (to force obfuscation use the allowDebug command line option)";
				throw new Exception(msg);
			}

			for (uint n = 1; n < abc.strings.length; ++n)
			{
				string name = abc.strings[n];

				if (name in fullRenames)
				{
					string rename = fullRenames[name];

					if (!opt.quiet || opt.verbose)
						writefln("ABC: %s => %s", name, rename);

					abc.strings[n] = rename;
				}
			}

			if (!sealed)
			{
				//abc.strings ~= opt.sealText;
				sealed = true;
			}

			replaceTagData(tag, abc.write(), false);
		}
	}

	void processSymTag(ref SWFFile.Tag tag)
	{
		SymFile sym = readTag!(SymFile)(tag);

		if (sym)
		{
			if (opt.verbose)
				writeln("SYM: Processing sym ...");

			if (opt.verbose)
				writefln("SYM: sym.symbols.length = %d", sym.symbols.length);

			foreach (ref symbol; sym.symbols)
			{
				if (opt.verbose)
					writefln("SYM: idref = %d, name = %s", symbol.idref, symbol.name);

				if (symbol.name in fullRenames)
				{
					string rename = fullRenames[symbol.name];

					if (!opt.quiet || opt.verbose)
						writefln("SYM: %s => %s", symbol.name, rename);

					symbol.name = rename;
				}
			}

			replaceTagData(tag, sym.write(), false);
		}
	}

	void processFrmTag(ref SWFFile.Tag tag)
	{
		FrmFile frm = readTag!(FrmFile)(tag);

		if (frm)
		{
			if (opt.verbose)
			{
				writefln("FRM: frameLabel %s", frm.frameLabel);
				writefln("FRM: hasAnchor %s", frm.hasAnchor);
			}

			if (frm.frameLabel in fullRenames)
			{
				string rename = fullRenames[frm.frameLabel];

				if (!opt.quiet || opt.verbose)
					writefln("FRM: %s => %s", frm.frameLabel, rename);

				frm.frameLabel = rename;
			}

			replaceTagData(tag, frm.write(), false);
		}
	}

	void processSprTag(ref SWFFile.Tag tag, ubyte swfver)
	{
		SprFile spr = readTag!(SprFile)(tag);

		if (spr)
		{
			if (opt.verbose)
			{
				writefln("SPR: spriteId %s", spr.spriteId);
				writefln("SPR: frameCount %s", spr.frameCount);
			}

			foreach (count, ref sprtag; spr.tags)
			{
				if (opt.verbose)
					writefln("SPR: %d %s %d %s %s", count, tagNames[sprtag.type], sprtag.length,
							 sprtag.forceLongLength ? "true" : "false", getHexString(sprtag.data));

				processTag(sprtag, swfver);
			}

			replaceTagData(tag, spr.write(), false);
		}
	}

	void processPobTag(ref SWFFile.Tag tag, ubyte ver)
	{
		PobFile pob = readTagVer!(PobFile)(tag, ver);

		if (pob)
		{
			if (opt.verbose)
				writeln("POB: " ~ pob.toString());

			if (pob.hasName && pob.name in fullRenames)
			{
				string rename = fullRenames[pob.name];

				if (!opt.quiet || opt.verbose)
					writefln("POB: %s => %s", pob.name, rename);

				pob.name = rename;
			}

			if (pob.hasClassName && pob.className in fullRenames)
			{
				string rename = fullRenames[pob.className];

				if (!opt.quiet || opt.verbose)
					writefln("POB: %s => %s", pob.className, rename);

				pob.className = rename;
			}

			replaceTagData(tag, pob.write(), false);
		}
	}

	void processImpTag(ref SWFFile.Tag tag)
	{
		ImpFile imp = readTag!(ImpFile)(tag);

		if (imp)
		{
			foreach(ref a; imp.assets)
				if (a.name in fullRenames)
				{
					string rename = fullRenames[a.name];

					if (!opt.quiet || opt.verbose)
						writefln("IMP: %s => %s", a.name, rename);

					a.name = rename;
				}

			replaceTagData(tag, imp.write(), false);
		}
	}

	void processExpTag(ref SWFFile.Tag tag)
	{
		ExpFile exp = readTag!(ExpFile)(tag);

		if (exp)
		{
			foreach(ref a; exp.assets)
				if (a.name in fullRenames)
				{
					string rename = fullRenames[a.name];

					if (!opt.quiet || opt.verbose)
						writefln("EXP: %s => %s", a.name, rename);

					a.name = rename;
				}

			replaceTagData(tag, exp.write(), false);
		}
	}

	void processBinTag(ref SWFFile.Tag tag)
	{
		uint[string] jsonRenames;

		void renameKeys(ref JSONValue root)
		{
			void renameKeysObject(ref JSONValue root)
			{
				if (root.type != JSON_TYPE.OBJECT)
					return;

				bool[string] result;

				foreach (k, ref v; root.object)
				{
					if (k in fullRenames)
						result[k] = true;
					renameKeys(v);
				}

				foreach (ref k; result.keys)
				{
					++jsonRenames[k];
					root.object[fullRenames[k]] = root[k];
					root.object.remove(k);
				}
			}

			void renameKeysArray(ref JSONValue root)
			{
				if (root.type != JSON_TYPE.ARRAY)
					return;

				foreach (r; root.array)
					renameKeys(r);
			}

			renameKeysObject(root);
			renameKeysArray(root);
		}

		BinFile bin = readTag!(BinFile)(tag);

		if (bin && find(jsonIds, bin.characterId) != [])
		{
			JSONValue j = parseJSON(bin.binaryData);

			renameKeys(j);

			bin.binaryData = cast(ubyte[])toJSON(&j);

			if (opt.verbose)
				writefln("BIN: %d %s %s", bin.characterId, opt.jsonNames, jsonIds);

			if (!opt.quiet || opt.verbose)
				foreach (ref r; jsonRenames.keys)
					writefln("BIN: %s => %s", r, fullRenames[r]);

			replaceTagData(tag, bin.write(), false);
		}
	}

	void checkEnableDebuggerTags(ref SWFFile.Tag tag)
	{
		if (!opt.allowDebug && (tag.type == TagType.EnableDebugger || tag.type == TagType.EnableDebugger2))
		{
			const string msg = "EnableDebugger tag found! (to force obfuscation use the allowDebug command line option)";
			throw new Exception(msg);
		}
	}

	void processTag(ref SWFFile.Tag tag, ubyte swfver)
	{
		checkEnableDebuggerTags(tag);

		processAbcTag(tag);
		processBinTag(tag);
		processExpTag(tag);
		processFrmTag(tag);
		processImpTag(tag);
		processPobTag(tag, swfver);
		processSprTag(tag, swfver);
		processSymTag(tag);
	}

	void processSwf(string swfName)
	{
		SWFFile swf = SWFFile.read(cast(ubyte[])read(swfName));

		foreach (uint count, ref tag; swf.tags)
		{
			if (opt.verbose)
				writefln("SWF: %d %s %d %s %s", count, tagNames[tag.type], tag.length,
						 tag.forceLongLength ? "true" : "false", toHexString(md5Of(tag.data)));

			generateFullRenames(tag);
		}

		fullRenames.rehash();

		foreach(ref f; fixedNames.keys)
			if (f in fullRenames)
			{
				if (opt.verbose)
					writefln("SWF: Fixed name [%s] renamed to [%s] instead of [%s]", f, fixedNames[f], fullRenames[f]);

				fullRenames[f] = fixedNames[f];
			}

		foreach (uint count, ref tag; swf.tags)
		{
			if (opt.verbose)
				writefln("SWF: %d %s %d %s %s", count, tagNames[tag.type], tag.length,
						 tag.forceLongLength ? "true" : "false", toHexString(md5Of(tag.data)));

			processTag(tag, swf.header.ver);
		}

		jsonIds.clear();

		std.file.write(swfName ~ "." ~ opt.outputExt, swf.write());
	}

	void reportWarnings()
	{
		foreach(ref f; fixedNames.keys)
			if (f !in fullRenames)
				stderr.writeln("Warning: Fixed name [" ~ f ~ "] skipped because it doesn't qualify for obfuscation.");
	}
}
