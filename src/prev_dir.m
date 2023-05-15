% ## Copyright (C) 2023 HELICS-User
% ## 
% ## This program is free software: you can redistribute it and/or modify it
% ## under the terms of the GNU General Public License as published by
% ## the Free Software Foundation, either version 3 of the License, or
% ## (at your option) any later version.
% ## 
% ## This program is distributed in the hope that it will be useful, but
% ## WITHOUT ANY WARRANTY; without even the implied warranty of
% ## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% ## GNU General Public License for more details.
% ## 
% ## You should have received a copy of the GNU General Public License
% ## along with this program.  If not, see
% ## <https://www.gnu.org/licenses/>.
% 
% ## -*- texinfo -*- 
% ## @deftypefn {} {@var{retval} =} prev_dir (@var{input1}, @var{input2})
% ##
% ## @seealso{}
% ## @end deftypefn
% 
% ## Author: HELICS-User <helics-user@helicsuser-VirtualBox>
% ## Created: 2023-05-11

function src_dir = prev_dir ()
    src_dir = pwd;
    prev_idx = 0;
    for i = 1:sizeof(src_dir)
      if (src_dir(sizeof(src_dir)+1-i) == '/') && (prev_idx == 0)
        prev_idx = sizeof(src_dir)+1-i;
      end
    end
    if prev_idx>1
      wrapper_dir = src_dir(1:prev_idx-1);
      cd(wrapper_dir)
    else
      fprintf('error: no higher directory found')
    end


end
