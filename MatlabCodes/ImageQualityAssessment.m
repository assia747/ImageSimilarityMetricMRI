%% Function to estimate the image quality score

% This function can be called to get the image label in terms of its
% quality. The input is a 2D MR image, and after segmentation, feature
% extraction, feature dimension reduction, the feature vector will be
% examined with the model will be generated by the user assigned parameters
% in InputParameters. The default model has been generated by the first 36
% PCs and 10-folds cross-validation.


% Input Parameters:     - Image: A 2D image. In case of color image, it
%                         will be changed to gray scale
%                       - InputParameters : A structure containing the
%                         parameter settings as below:
%                         'NUM_PC' -> the number of first PCs (default= 36)
%                         'Folds' -> 5 or 10 for k-folds cross-validation (default=8)

% Output Parameter:     - EstimatedLabel: An integer between 1 to 5
%                       representing the class label for input image
%                       - ComputationalCost: Computational time for the
%                       whole process for the given image


function [EstimatedLabel , ComputationalCost] = ImageQualityAssessment (Image2D,InputParameters)



%% adds all required folder to the matlab path
DirName = cd;
Folders = dir((fullfile(DirName)));
FoldersName = {Folders.name}';

base = cd;
if ispc
    addpath(strcat(base,'\','LIBSVM'));
elseif isunix
    addpath(strcat(base,'/','LIBSVM'));
end


for n=3:1:size(FoldersName,1)
    SubFolders = dir (FoldersName{n});
    SubFoldersName = {SubFolders.name}';
    if size(SubFoldersName,1) ==1
        if ispc
            addpath(strcat('"',base,'\',FoldersName{n}, '"'));
        elseif isunix
            addpath(strcat('"',base,'/',FoldersName{n},'"'));
        end
    else
        m=3:1:size(SubFoldersName,1);
        if ispc
            addpath(strcat('"',base,'\',SubFoldersName{m}, '"'));
        elseif isunix
            addpath(strcat('"',base,'/',SubFoldersName{m},'"'));
        end
    end
end


addpath(strcat(base,'/','Codes_Classifications'));
addpath(strcat(base,'/','Codes_Segmentation'));
addpath(strcat(base,'/','Codes_FeatureExtraction'));




% Input MR image
Image2D;

%% Default for input Parameters

if exist('InputParameters','var') == 0 || isfield(InputParameters,'NUM_PC') == 0
    InputParameters.NUM_PC = 36;
end

if exist('InputParameters','var') == 0 || isfield(InputParameters,'Folds') == 0
    InputParameters.Folds = 10;
end

NUM_PC = InputParameters.NUM_PC;
Folds = InputParameters.Folds;

Name = strcat('Result_Training_RBF_', num2str(NUM_PC),'_', num2str(Folds),'.mat');

if exist('InputParameters','var') == 0
    display(' no such file or directory')
else
    %% Segmentation and feature extraction for a 2d image
    
    
    % Parameter Setting
    
    values = [1;2;4;8;16;32;64;128];
    offset0 = [zeros(size(values,1),1) values];
    offset1 = [-values values];
    offset2 = [-values zeros(size(values,1),1)];
    offset3 = [-values -values];
    offset = [offset0 ; offset1 ; offset2 ; offset3];
    GLCMParameters.DisplacementVector = offset;
    GLCMParameters.NumLevels = 255;
    RadialLBP = [8 1; 16 2;24 3;32 4];
    
    
    % Segmentation
    % Input Parameters:
    %            - Image: The 2D MR slice (Image2D)
    %            - Margin: Rectangular initial mask with 10 pixels from the
    %              border of image
    %            - Iteration: 1000
    %            - Smoothness: 4
    %            - FlagShow: 0 (show no results)
    tic
    [SegmentedImage BinaryImage] = Segmentation(Image2D, 10 , 1000, 4,0);
    
    % 255 level scale
    % I is the Image for feature Extraction
    I = floor(mat2gray(SegmentedImage)*255);
    
    %_________ Feature extraction ___________
    
    
    % 1. Gray Level Co-occurance Mtarix feature extraction (1x672)
    feat_cooc(1,:) = GLCM (I, GLCMParameters);
    
    % 2. Run-Length feature extraction (1x44)
    feat_rle(1,:) = RunLength(I);
    
    % 3. Gabor Filters feature extraction (1x1080)
    % 40 filters (8 orientations, 5 scales)
    GaborResult = Gabor(5,8,I,0);
    feat_gabor(1,:) = real(GaborFilter(GaborResult));
    
    % 4. Local Binary Pattern feature extraction (1x1024)
    feat_lbp(1,:) = LocalBinaryPattern(I, RadialLBP);
    
    % 5. Fractal feature extraction (1x30)
    feat_fractal(1,:) = FractalDimension(I,0);
    
    % 6. Gradient-Based feature extraction (1x24)
    feat_gradient(1,:)  = GradientBased(I);
    
    
    Sample = [feat_cooc feat_rle feat_gabor feat_lbp feat_fractal feat_gradient];
    
    
    %% Normalization of the sample by zero mean and unit variance
    NormSample = zscore(Sample);
    t1 = toc;
    
    %% load the PCA Results to reduce the feature dimension
    a = load('PCAResults.mat');
    PCAOut = a.PCAOut;
    PCs = PCAOut.PCs;
    
    tic
    % Mapping the sample into new feature space
    TransformedData = (NormSample*PCs);
    t2 = toc;
    
    % Loading the training set with the corresponding labels.
    % The last column shows the corresponding class labels.
    
    c = load('TrainDataPCA.mat');
    TrainData = c.TrainData;
    data = TrainData(:,1:NUM_PC);
    labels = TrainData(:,end);
    %% Loading the best parameter setting which has been already generated
    
    b = load(Name);
    BestParammeters =  b.Result;
    
    C = BestParammeters(1,1);
    Gamma = BestParammeters(1,2);
    
    %_______________ Create the Model _____________
    
    Model = svmtrain(labels,data, sprintf('-t 2 -c %f -g %f', C, Gamma));
    
    %____________________ Test ____________________
    tic
    [EstimatedLabel] = svmpredict(1,TransformedData, Model);
    t3 = toc;
    ComputationalCost = t1 + t2 +t3;
    
end

