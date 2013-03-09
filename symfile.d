/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is part of RABCDAsm.
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

module symfile;

import std.string : format;
import std.exception;

import swffile;
import tagreader;
import tagwriter;

final class SymFile
{
	SymbolClass[] symbols;

	struct SymbolClass
	{
		ushort idref;
		string name;
	}

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.SymbolClass;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static SymFile read(ubyte[] data)
	{
		return (new SymReader(data)).sym;
	}

	ubyte[] write()
	{
		return (new SymWriter(this)).buf;
	}
}

private final class SymReader : TagReader
{
	SymFile sym;

	this(ubyte[] buf)
	{
		try
		{
			super(buf);
			sym = new SymFile();

			static uint atLeastOne(uint n)
			{
				return n ? n : 1;
			}

			sym.symbols.length = atLeastOne(readU16());
			foreach (ref value; sym.symbols[0..$])
				value = readSymbolClass();
		}
		catch (Exception e)
			throw new Exception(format("Error at %d (0x%X):", pos, pos), e);
	}

	SymFile.SymbolClass readSymbolClass()
	{
		SymFile.SymbolClass s;
		s.idref = readU16();
		s.name = readStringZ();
		return s;
	}
}

private final class SymWriter : TagWriter
{
	SymFile sym;

	this(SymFile sym)
	{
		this.sym = sym;

		writeU16(cast(ushort)sym.symbols.length);

		foreach(symbol; sym.symbols)
		{
			writeU16(symbol.idref);
			writeStringZ(symbol.name);
		}

		buf.length = pos;
	}
}

