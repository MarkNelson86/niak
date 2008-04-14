function [] = niak_montage(vol,opt)

% Visualization of a 3D volume in a montage style (all slices in one image)
%
% SYNTAX:
% []=niak_montage(vol,opt)
%
% INPUTS:
% VOL           (3D array) a 3D volume
% OPT           (structure, optional) has the following fields:
%
%                   TYPE_SLICE (string, default 'axial') the plane of slices
%                       in the montage. Available options : 'axial', 'coronal',
%                       'sagital'. This option assumes the volume is in
%                       'xyz' convention (left to right, posterior to
%                       anterior, ventral to dorsal).
%
%                   VOL_LIMITS (vector 2*1, default [min(vol(:)) max(vol(:))]) 
%                       limits of the color scaling.
%
%                   TYPE_COLOR (string, default 'jet') colormap name.
%
%                   FWHM_SMOOTH (double, default 0) smooth the image with a 
%                       isotropic Gaussian kernel of SMOOTH fwhm (in voxels).
%
%                   TYPE_FLIP (boolean, default 'rot90') make rotation and
%                           flip of the slice representation. see
%                           niak_flip_vol for options. 'rot90' will work
%                           for images whose voxels is x/y/z respectively
%                           oriented from left to right, from anterior to
%                           posterior, and from ventral to dorsal. In this
%                           case, left is left on the image.
%
% OUTPUTS:
% a 'montage' style visualization of each slice of the volume
%
% COMMENTS:
%
% Copyright (c) Pierre Bellec, McConnell Brain Imaging Center,
% Montreal Neurological Institute, McGill University, 2008.
% Maintainer : pbellec@bic.mni.mcgill.ca
% See licensing information in the code.
% Keywords : medical imaging, montage, visualization

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

% Setting up default
gb_name_structure = 'opt';
gb_list_fields = {'type_slice','vol_limits','type_color','fwhm','type_flip'};
gb_list_defaults = {'axial',[min(vol(:)) max(vol(:))],'jet',0,'rot90'};
niak_set_defaults

colormap(type_color);

if strcmp(type_slice,'coronal');

    vol = permute(vol,[1 3 2]);

elseif strcmp(type_slice,'sagital');

    vol = permute(vol,[2 3 1]);

elseif strcmp(type_slice,'axial')

else
    fprintf('%s is an unkwon view type.\n',type_slice);
    return
end

[nx,ny,nz] = size(vol);

N = ceil(sqrt(nz));
M = ceil(nz/N);

if fwhm_smooth>0
    opt_smooth.fwhm = opt.fwhm;
    vol = niak_smooth_vol(vol,opt_smooth);
end

if strcmp(type_flip,'rot270')|strcmp(type_flip,'rot90')
    vol2 = zeros([nx*N ny*M]);
else
    vol2 = zeros([ny*N nx*M]);
end

[indy,indx] = find(ones([M,N]));
ind = find(ones([M*N]));

for num_z = 1:nz
    if strcmp(type_flip,'rot270')|strcmp(type_flip,'rot90')
        vol2(1+(indx(num_z)-1)*ny:indx(num_z)*ny,1+(indy(num_z)-1)*nx:indy(num_z)*nx) = niak_flip_vol(squeeze(vol(:,:,ind(num_z))),type_flip);
    else
        vol2(1+(indx(num_z)-1)*nx:indx(num_z)*nx,1+(indy(num_z)-1)*ny:indy(num_z)*ny) = niak_flip_vol(squeeze(vol(:,:,ind(num_z))),type_flip);
    end
end

imagesc(vol2,vol_limits)
