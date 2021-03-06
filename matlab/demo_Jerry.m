% Demo of using corpca.m for CORPCA
% This function has written based on Programs from Matlab
%     Copyright (c) 2017, Huynh Van Luong, version 01, Jan. 24, 2017
%     Multimedia Communications and Signal Processing, University of Erlangen-Nuremberg.
%     All rights reserved.
%
%     PUBLICATION: Huynh Van Luong, N. Deligiannis, J. Seiler, S. Forchhammer, and A. Kaup,
%             "Incorporating Prior Information in Compressive Online Robust Principal Component Analysis,"
%              in e-print, arXiv, Jan. 2017.
%
%
%% Loading video/images
addpath(genpath('./')); % Add functions to path
readVideo = false;      % Read video or images
resizeScale = 0.2;        % Scale to resize image.
c = 1;            % Number of Used channels.
                        % chanUse=1 means using gray images and =3 using RGB images
nClip = 30;
disp('Loading data...');
tic

if readVideo
    imagefiles = VideoReader('./videos/bridge.avi');
    vRaw = read(imagefiles,[1,nClip]); % Read video. Size: (60,80,3,nClip)
    [h0, w0, c0, nFrame] = size(vRaw);   % Get size
    h = floor(h0 * resizeScale);
    w = floor(w0 * resizeScale);
    c = min(c, c0);          % Correct chanUse

    if c == 1
        vRawClip = imresize(rgb2gray(vRaw(:, :, :, 1:nClip)), [h, w]);
    else
        vRawClip = imresize(vRaw(:, :, :, 1:nClip), [h, w]);
    end

    images = double(reshape(vRawClip, [h * w * c, nClip]));
else
    fpath = './videos/bridge/';
    imagefiles = dir('./videos/bridge/*.jpg');
    nfiles = length(imagefiles); % Number of files found
% 
    [h0, w0, c0] = size(imread([fpath, imagefiles(1).name]));

    h = floor(h0 * resizeScale);
    w = floor(w0 * resizeScale);
    c = min(c, c0);          % Correct chanUse
    images = zeros([h * w * c, nfiles]); % image size (120,160,3)
    %xiaojian
%     cropsize = [113 583 554 411];
%     
%     cropImg = imcrop(imread([fpath, imagefiles(1).name]),cropsize);
%     [h0, w0, c0] = size(cropImg);
%     h = floor(h0 * resizeScale);
%     w = floor(w0 * resizeScale);
%     c = min(c, c0);          % Correct chanUse
%     images = zeros([h * w * c, nfiles]); % image size (120,160,3)

    for ii = 1:nfiles
        currentfilename = imagefiles(ii).name;
        %xiaojian
        currentimage = imread([fpath, currentfilename]);

        if c == 1
            currentimage = imresize(rgb2gray(currentimage), resizeScale);
        else
            currentimage = imresize(currentimage, resizeScale);
        end

        images(:, ii) = currentimage(:);
    end

end

toc;
%readTimeEnd = toc;

%% Setting Parameters
nSI = 3;        % Size of number of foreground prior information
m = h * w * c;  % a number of measurements of reduced data
n = h * w * c;  % Dimension of data vectors
q = 30;         % the number of testing vectors

if m == n
    G = eye(m, n);
    Phi = eye(m, n);
else
    Phi = randn(m, n); % Input the measurement matrix
    fprintf('PINV'); tic
    G = pinv(Phi);
    fprintf('PINV finish'); toc
end

% Get data for CORPCA
%     trainData: Traning data
%     M= L + S: Testing data
trainData = images(:, 1:q);
% M = images(:,100+1:100+q);
M = trainData;

% Add noise to video
addNoise = false;

if addNoise
    noisyFrameNum = floor(q*0.3);
    noisyFrameIdice = randperm(q, noisyFrameNum);
    for idx = 1:noisyFrameNum
        currentimage = reshape(M(:,noisyFrameIdice(idx)),[h,w,c]);
        currentimageNoisy = imnoise(currentimage, 'gaussian', 0, 0.5);
        M(:,noisyFrameIdice(idx)) = currentimageNoisy(:);
    end

end

% Initializing background and foreground prior information via an offline rpca
RPCA_lambda = 1 / sqrt(size(trainData, 1));
[B0, Z0, ~] = inexact_alm_rpca(trainData, RPCA_lambda, -1, 20);

%% Running CORPCA
%--------------------------------------------------------------------------------------------------
%--- Input: observation yt with m measurements, projection matrix Phi, prior information Btm1, Ztm1
%--- Output: recovered foreground xt, background vt, the prior information updates, Bt, Zt
%--------------------------------------------------------------------------------------------------
Btm1 = B0; % Input background prior
Ztm1 = Z0(:, end - nSI + 1:end); % Input foreground prior
fgs = zeros(h0, w0, c, q);
bgs = zeros(h0, w0, c, q);
tic;

for t = 1:q
    fprintf('Testing fame %d at a measurement rate %2.2f \n', t, m / n);

    yt = Phi * M(:, t); % Input observation
    [xt, vt, Zt, Bt, beta, Wk] = corpca_Jerry(yt, {Phi, G, G * yt}, Ztm1, Btm1); % Performing CORPCA for separation
    % update prior information
    Ztm1 = Zt;
    Btm1 = Bt;

    fgs(:, :, :, t) = imresize(reshape(xt, [h, w, c]), 1 / resizeScale);
    bgs(:, :, :, t) = imresize(reshape(vt, [h, w, c]), 1 / resizeScale);

end


toc;
%fgs = reshape(fgs, [h,w,1,q]);
%figure;montage(fgs)
%img = reshape(fg,[120,160]);

%% Running CORPCA-OF
%--------------------------------------------------------------------------------------------------
%--- Input: observation yt with m measurements, projection matrix Phi, prior information Btm1, Ztm1
%--- Output: recovered foreground xt, background vt, the prior information updates, Bt, Zt
%--------------------------------------------------------------------------------------------------
Btm1OF = B0; % Input background prior
Ztm1OF = Z0(:, end - nSI + 1:end); % Input foreground prior
fgsOF = zeros(h0, w0, c, q);
bgsOF = zeros(h0, w0, c, q);
tic;

for t = 1:q
    fprintf('Testing fame %d at a measurement rate %2.2f \n', t, m / n);
    fprintf('Updating proir by optical flow...\n');

    % Compute optical flow
    Ztm1OFReshape = reshape(Ztm1OF, [h, w, c, nSI]);

    if c ~= 1
        %Ztm1OFReshapeGray = rgb2gray(Ztm1OFReshape);
        Ztm1OFReshapeGray = squeeze(Ztm1OFReshape(:, :, 1, :));
    else
        Ztm1OFReshapeGray = squeeze(Ztm1OFReshape);
    end

    of12 = computeOF(Ztm1OFReshapeGray(:, :, end - 2 + 1), Ztm1OFReshapeGray(:, :, end - 1 + 1));
    of13 = computeOF(Ztm1OFReshapeGray(:, :, end - 3 + 1), Ztm1OFReshapeGray(:, :, end - 1 + 1));

    % Motion Compensation
    Ztm1OF(:, end - 2 + 1) = linearOFCompensate(reshape(Ztm1OF(:, end - 2 + 1), [h, w, c]), of12, 1, true);
    Ztm1OF(:, end - 3 + 1) = linearOFCompensate(reshape(Ztm1OF(:, end - 3 + 1), [h, w, c]), of13, 0.5, true);

    fprintf('Optimizing...\n');
    yt = Phi * M(:, t); % Input observation
    [xt, vt, Zt, Bt, beta, Wk] = corpca_Jerry(yt, {Phi, G, G * yt}, Ztm1OF, Btm1OF); % Performing CORPCA for separation

    % update prior information
    Ztm1OF = Zt;
    Btm1OF = Bt;

    fgsOF(:, :, :, t) = imresize(reshape(xt, [h, w, c]), 1 / resizeScale);
    bgsOF(:, :, :, t) = imresize(reshape(vt, [h, w, c]), 1 / resizeScale);

end

toc;
%% save resutls

save('./results/bri/fgs.mat','fgs');
save('./results/bri/bgs.mat','bgs');
save('./results/bri/fgsOF.mat','fgsOF');
save('./results/bri/bgsOF.mat','bgsOF');

%%
frameRate = 15;
utils.saveVideo('./fbVideos/bri/fgs', abs(fgs), frameRate);
utils.saveVideo('./fbVideos/bri/bgs', abs(bgs), frameRate);
utils.saveVideo('./fbVideos/bri/fgsOF', abs(fgsOF), frameRate);
utils.saveVideo('./fbVideos/bri/bgsOF', abs(bgsOF), frameRate);

% fileFormat = 'avi';
% saveVideo('./fbVideos/fgs', abs(fgs), frameRate, fileFormat);
% saveVideo('./fbVideos/bgs', abs(bgs), frameRate, fileFormat);
% saveVideo('./fbVideos/fgsOF', abs(fgsOF), frameRate, fileFormat);
% saveVideo('./fbVideos/bgsOF', abs(bgsOF), frameRate, fileFormat);
% disp('Finish Saving!')

%% Show Results
% Reshale results
MReshape = uint8(reshape(M, [h0, w0, c0, q]));
fgsReshape = uint8(reshape(fgs, [h0, w0, c0, q]));
bgsReshape = uint8(reshape(bgs, [h0, w0, c0, q]));
fgsOFReshape = uint8(reshape(fgsOF, [h0, w0, c0, q]));
bgsOFReshape = uint8(reshape(bgsOF, [h0, w0, c0, q]));

% Real image, foreground and backgrund comparsion
plotOptions = containers.Map;
plotOptions('Show Comparsion') = true;
plotOptions('Show COPRCA Foreground') = false;
plotOptions('Show COPRCA Background') = false;
plotOptions('Show COPRCA-OF Foreground') = false;
plotOptions('Show COPRCA-OF Background') = false;

if plotOptions('Show Comparsion')
    figure;
    subplot(2, 3, 1); imshow(MReshape(:, :, :, end)); title('Original Image');
    subplot(2, 3, 2); imshow(bgsReshape(:, :, :, end)); title('Background of COPRCA');
    subplot(2, 3, 3); imshow(fgsReshape(:, :, :, end)); title('Foreground of COPRCA');
    subplot(2, 3, 4); imshow(MReshape(:, :, :, end)); title('Original Image');
    subplot(2, 3, 5); imshow(bgsOFReshape(:, :, :, end)); title('Background of COPRCA-OF');
    subplot(2, 3, 6); imshow(fgsOFReshape(:, :, :, end)); title('Foreground of COPRCA-OF');
end

% CORPCA Foreground
if plotOptions('Show COPRCA Foreground')
    figure; montage(fgsReshape(:, :, :, end - 10 + 1:end)); title('CORPCA Foreground')
end

% CORPCA Background
if plotOptions('Show COPRCA Background')
    figure; montage(bgsReshape(:, :, :, end - 10 + 1:end)); title('CORPCA Background')
end

% CORPCA-OF Foreground
if plotOptions('Show COPRCA-OF Foreground')
    figure; montage(fgsOFReshape(:, :, :, end - 10 + 1:end)); title('CORPCA-OF Foreground')
end

% CORPCA-OF Background
if plotOptions('Show COPRCA-OF Background')
    figure; montage(bgsOFReshape(:, :, :, end - 10 + 1:end)); title('CORPCA-OF Background')
end

%% Utility functions
function of = computeOF(img1, img2, method)

    if nargin == 2
        method = 'LK';
    end

    if strcmp(method, 'LK')
        ofestmator = opticalFlowLK('NoiseThreshold', 0.009);
        estimateFlow(ofestmator, img1);
        of = estimateFlow(ofestmator, img2);
    end

end

function saveVideo(vFileName, vVar, frameRate, vFileSuffix)
    if nargin ==1
        error('Too few inputs!');
    elseif nargin == 2
        frameRate = 30;
        vFileSuffix = 'avi';
        vFileFormat = 'Motion JPEG AVI';
    elseif nargin ==3
        vFileSuffix = 'avi';
        vFileFormat = 'Motion JPEG AVI';
    else
        if strcmp(vFileSuffix, 'avi')
            vFileFormat = 'Motion JPEG AVI';
        elseif strcmp(vFileSuffix, 'mp4')
            vFileFormat = 'MPEG-4';
        end
    end
    
    
    vFileName = [vFileName '.' vFileSuffix];
    
    if isa(vVar, 'uint8')
        vVar = double(vVar);        
    end
    
    vVar = (vVar - min(vVar(:))) / max(vVar(:));
    disp(vFileFormat)
    vFile = VideoWriter(vFileName, vFileFormat);
    vFile.FrameRate = frameRate;
    open(vFile);
    writeVideo(vFile, vVar);
    close(vFile);
end
