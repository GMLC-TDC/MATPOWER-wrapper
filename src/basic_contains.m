## Copyright (C) 2023 HELICS-User
## 
## This program is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see
## <https://www.gnu.org/licenses/>.

## -*- texinfo -*- 
## @deftypefn {} {@var{retval} =} basic_contains (@var{input1}, @var{input2})
##
## @seealso{}
## @end deftypefn

## Author: HELICS-User <helics-user@helicsuser-VirtualBox>
## Created: 2023-05-11

function found = basic_contains (full_str, pattern)
full_str_length = sizeof(full_str);
pattern_length = sizeof(pattern);
found = 0;
for i = 1:full_str_length-pattern_length+1
  if full_str(i:i+pattern_length-1) == pattern
    found = 1;
  endif
endfor
endfunction
