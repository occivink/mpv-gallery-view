-- code below is a combination of:
--     sha256 implementation from http://lua-users.org/wiki/SecureHashAlgorithm
--     lua implementation of bit32 (used as fallback on lua5.1) from
--     https://www.snpedia.com/extensions/Scribunto/includes/engines/LuaCommon/lualib/bit32.lua
-- both are licensed under the MIT below:

local band, rrotate, bxor, rshift, bnot

if bit32 then
    band, rrotate, bxor, rshift, bnot = bit32.band, bit32.rrotate, bit32.bxor, bit32.rshift, bit32.bnot
else
    ---
    -- An implementation of the lua 5.2 bit32 library, in pure Lua

    -- Note that in Lua, "x % n" is defined such that will always return a number
    -- between 0 and n-1 for positive n. We take advantage of that a lot here.

    local function checkint( name, argidx, x, level )
    	local n = tonumber( x )
    	if not n then
    		error( string.format(
    			"bad argument #%d to '%s' (number expected, got %s)",
    			argidx, name, type( x )
    		), level + 1 )
    	end
    	return math.floor( n )
    end

    local function checkint32( name, argidx, x, level )
    	local n = tonumber( x )
    	if not n then
    		error( string.format(
    			"bad argument #%d to '%s' (number expected, got %s)",
    			argidx, name, type( x )
    		), level + 1 )
    	end
    	return math.floor( n ) % 0x100000000
    end


    bnot = function( x )
    	x = checkint32( 'bnot', 1, x, 2 )

    	-- In two's complement, -x = not(x) + 1
    	-- So not(x) = -x - 1
    	return ( -x - 1 ) % 0x100000000
    end

    ---
    -- Logic tables for and/or/xor. We do pairs of bits here as a tradeoff between
    -- table space and speed. If you change the number of bits, also change the
    -- constants 2 and 4 in comb() below, and the initial value in bit32.band and
    -- bit32.btest
    local logic_and = {
    	[0] = { [0] = 0, 0, 0, 0},
    	[1] = { [0] = 0, 1, 0, 1},
    	[2] = { [0] = 0, 0, 2, 2},
    	[3] = { [0] = 0, 1, 2, 3},
    }
    local logic_xor = {
    	[0] = { [0] = 0, 1, 2, 3},
    	[1] = { [0] = 1, 0, 3, 2},
    	[2] = { [0] = 2, 3, 0, 1},
    	[3] = { [0] = 3, 2, 1, 0},
    }

    ---
    -- @param name string Function name
    -- @param args table Function args
    -- @param nargs number Arg count
    -- @param s number Start value, 0-3
    -- @param t table Logic table
    -- @return number result
    local function comb( name, args, nargs, s, t )
    	for i = 1, nargs do
    		args[i] = checkint32( name, i, args[i], 3 )
    	end

    	local pow = 1
    	local ret = 0
    	for b = 0, 31, 2 do
    		local c = s
    		for i = 1, nargs do
    			c = t[c][args[i] % 4]
    			args[i] = math.floor( args[i] / 4 )
    		end
    		ret = ret + c * pow
    		pow = pow * 4
    	end
    	return ret
    end

    band = function( ... )
    	return comb( 'band', { ... }, select( '#', ... ), 3, logic_and )
    end

    bxor = function( ... )
    	return comb( 'bxor', { ... }, select( '#', ... ), 0, logic_xor )
    end

    -- For the shifting functions, anything over 32 is the same as 32
    -- and limiting to 32 prevents overflow/underflow
    local function checkdisp( name, x )
    	x = checkint( name, 2, x, 3 )
    	return math.min( math.max( -32, x ), 32 )
    end

    rshift = function( x, disp )
    	x = checkint32( 'rshift', 1, x, 2 )
    	disp = checkdisp( 'rshift', disp )

    	return math.floor( x / 2^disp ) % 0x100000000
    end

    rrotate = function( x, disp )
    	x = checkint32( 'rrotate', 1, x, 2 )
    	disp = -checkint( 'rrotate', 2, disp, 2 ) % 32

    	local x = x * 2^disp
    	return ( x % 0x100000000 ) + math.floor( x / 0x100000000 )
    end
end

local string, setmetatable, assert = string, setmetatable, assert

_ENV = nil

-- Initialize table of round constants
-- (first 32 bits of the fractional parts of the cube roots of the first
-- 64 primes 2..311):
local k = {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
   0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
   0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
   0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
   0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
   0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
   0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
   0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
   0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}


-- transform a string of bytes in a string of hexadecimal digits
local function str2hexa (s)
  local h = string.gsub(s, ".", function(c)
              return string.format("%02x", string.byte(c))
            end)
  return h
end


-- transform number 'l' in a big-endian sequence of 'n' bytes
-- (coded as a string)
local function num2s (l, n)
  local s = ""
  for i = 1, n do
    local rem = l % 256
    s = string.char(rem) .. s
    l = (l - rem) / 256
  end
  return s
end

-- transform the big-endian sequence of four bytes starting at
-- index 'i' in 's' into a number
local function s232num (s, i)
  local n = 0
  for i = i, i + 3 do
    n = n*256 + string.byte(s, i)
  end
  return n
end


-- append the bit '1' to the message
-- append k bits '0', where k is the minimum number >= 0 such that the
-- resulting message length (in bits) is congruent to 448 (mod 512)
-- append length of message (before pre-processing), in bits, as 64-bit
-- big-endian integer
local function preproc (msg, len)
  local extra = -(len + 1 + 8) % 64
  len = num2s(8 * len, 8)    -- original len in bits, coded
  msg = msg .. "\128" .. string.rep("\0", extra) .. len
  assert(#msg % 64 == 0)
  return msg
end


local function initH256 (H)
  -- (first 32 bits of the fractional parts of the square roots of the
  -- first 8 primes 2..19):
  H[1] = 0x6a09e667
  H[2] = 0xbb67ae85
  H[3] = 0x3c6ef372
  H[4] = 0xa54ff53a
  H[5] = 0x510e527f
  H[6] = 0x9b05688c
  H[7] = 0x1f83d9ab
  H[8] = 0x5be0cd19
  return H
end


local function digestblock (msg, i, H)

    -- break chunk into sixteen 32-bit big-endian words w[1..16]
    local w = {}
    for j = 1, 16 do
      w[j] = s232num(msg, i + (j - 1)*4)
    end

    -- Extend the sixteen 32-bit words into sixty-four 32-bit words:
    for j = 17, 64 do
      local v = w[j - 15]
      local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
      v = w[j - 2]
      local s1 = bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
      w[j] = w[j - 16] + s0 + w[j - 7] + s1
    end

    -- Initialize hash value for this chunk:
    local a, b, c, d, e, f, g, h =
        H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

    -- Main loop:
    for i = 1, 64 do
      local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
      local maj = bxor(band(a, b), band(a, c), band(b, c))
      local t2 = s0 + maj
      local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
      local ch = bxor (band(e, f), band(bnot(e), g))
      local t1 = h + s1 + ch + k[i] + w[i]

      h = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    end

    -- Add (mod 2^32) this chunk's hash to result so far:
    H[1] = band(H[1] + a)
    H[2] = band(H[2] + b)
    H[3] = band(H[3] + c)
    H[4] = band(H[4] + d)
    H[5] = band(H[5] + e)
    H[6] = band(H[6] + f)
    H[7] = band(H[7] + g)
    H[8] = band(H[8] + h)

end


local function finalresult256 (H)
  -- Produce the final hash value (big-endian):
  return
    str2hexa(num2s(H[1], 4)..num2s(H[2], 4)..num2s(H[3], 4)..num2s(H[4], 4)..
             num2s(H[5], 4)..num2s(H[6], 4)..num2s(H[7], 4)..num2s(H[8], 4))
end


----------------------------------------------------------------------
local HH = {}    -- to reuse

local function hash (msg)
  msg = preproc(msg, #msg)
  local H = initH256(HH)

  -- Process the message in successive 512-bit (64 bytes) chunks:
  for i = 1, #msg, 64 do
    digestblock(msg, i, H)
  end

  return finalresult256(H)
end

return { hash = hash }

