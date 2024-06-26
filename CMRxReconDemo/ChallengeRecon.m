function recon = ChallengeRecon(kspace, type, reconType, imgShow, isRadial)
% kspace: complex images with the dimensions (sx,sy,sc,sz,t/w)
% -sx: matrix size in x-axis
% -sy: matrix size in y-axis
% -sc: coil array number
% -sz: slice number (short axis view); slice group (long axis view)
% -t/w: time frame/weighting

% type = 0 means full kspace data
% type = 1 means subsampled data

% reconType = 0: perform zero-filling recon
% reconType = 1: perform GRAPPA recon
% reconType = 2: perform SENSE recon
% reconType = 3: perform both GRAPPA and SENSE recon

% imgShow = 0: ignore image imshow
% imgShow = 1: image imshow

% isRadial = 0: non-radial undersampling
% isRadial = 1: radial undersampling, smaller navigation area
    
if type == 0 
    % show full sampled/zero-filled image
    kspace_full = kspace;
    if length(size(kspace_full)) == 5
        [sx,sy,scc,sz,nPhase] = size(kspace_full);
    else
        [sx,sy,scc,sz] = size(kspace_full);
        nPhase = 1;
    end
    img_full = zeros(sx,sy,scc,sz,nPhase);
    img_full_sos = zeros(sx,sy,sz,nPhase);
    for ind1 = 1:sz
        for ind2 = 1:nPhase
            img_full(:,:,:,ind1,ind2) = ifft2c(kspace_full(:,:,:,ind1,ind2));
            if ndims(img_full(:,:,:,ind1,ind2)) >= 3
                img_full_sos(:,:,ind1,ind2) = sos(img_full(:,:,:,ind1,ind2));
            else
                img_full_sos(:,:,ind1,ind2) = abs(img_full(:,:,:,ind1,ind2));
            end
        end
    end
    if imgShow
        figure,imshow(abs(img_full_sos(:,:,1,1)),[0,0.001]); % ZF image
    end
    recon = img_full_sos;
else 
    % recon and save data
    ncalib = 16;
    kspace_sub = kspace;
    [sx,sy,scc,sz,nPhase] = size(kspace_sub);
    if isRadial
        kspace_cal = zeros(ncalib, ncalib, scc, sz, nPhase);
    else
        kspace_cal = zeros(sx,ncalib,scc,sz,nPhase);
    end
    img_zf = zeros(sx,sy,scc,sz,nPhase);
    img_sos = zeros(sx,sy,sz,nPhase);
    %% generate calibration data
    if isRadial
        if nPhase ~= 1
            for ind2 = 1:nPhase
                if sz == 1
                    kspace_calib = crop(kspace_sub(:,:,:,:,1),ncalib,ncalib,scc);
                else
                    kspace_calib = crop(kspace_sub(:,:,:,:,1),ncalib,ncalib,scc,sz);
                end
                kspace_cal(:,:,:,:,ind2) = kspace_calib;
            end
        else
            if sz == 1
                kspace_calib = crop(kspace_sub, ncalib, ncalib, scc);
            else
                kspace_calib = crop(kspace_sub, ncalib, ncalib, scc, sz);
            end
            kspace_cal = kspace_calib;
        end
    else
        if nPhase ~= 1
            for ind2 = 1:nPhase
                if sz == 1
                    kspace_calib = crop(kspace_sub(:,:,:,:,1),sx,ncalib,scc);
                else
                    kspace_calib = crop(kspace_sub(:,:,:,:,1),sx,ncalib,scc,sz);
                end
                kspace_cal(:,:,:,:,ind2) = kspace_calib;
            end
        else
            if sz == 1
                kspace_calib = crop(kspace_sub, sx, ncalib, scc);
            else
                kspace_calib = crop(kspace_sub, sx, ncalib, scc, sz);
            end
            kspace_cal = kspace_calib;
        end      
    end
    %% perform ZF recon
    if reconType == 0
        for ind1 = 1:sz
            for ind2 = 1:nPhase
                img_zf(:,:,:,ind1,ind2) = ifft2c(kspace_sub(:,:,:,ind1,ind2));
            if ndims(img_zf(:,:,:,ind1,ind2)) >= 3
                img_sos(:,:,ind1,ind2) = sos(img_zf(:,:,:,ind1,ind2));
            else
                img_sos(:,:,ind1,ind2) = abs(img_zf(:,:,:,ind1,ind2));
            end
            end
            disp(strcat(num2str(ind1),'/',num2str(sz)," completed!"));
        end
        if imgShow
            figure,imshow(abs(img_sos(:,:,1,1)),[0,0.001]); % ZF image
        end
        recon = img_sos;
    end
    %% GRAPPA recon
    if reconType == 1 || reconType == 3
        img_grappa = zeros(sx,sy,scc,sz,nPhase);
        kspace_grappa = zeros(sx,sy,scc,sz,nPhase);
        img_grappa_sos = zeros(sx,sy,sz,nPhase);
        % perform grappa recon
        for ind1 = 1:sz
            for ind2 = 1:nPhase
                [kspace_grappa(:,:,:,ind1,ind2),img_grappa(:,:,:,ind1,ind2)] = myGRAPPA(kspace_sub(:,:,:,ind1,ind2),kspace_cal(:,:,:,ind1,ind2),0);
                img_grappa_sos(:,:,ind1,ind2) = sos(img_grappa(:,:,:,ind1,ind2));
            end
            disp(strcat(num2str(ind1),'/',num2str(sz)," completed!"));
        end
        if imgShow
            figure,imshow(abs(img_grappa_sos(:,:,1,1)),[0,0.001]); % reconstructed image
        end
        recon = img_grappa_sos;
    end
    %% SENSE recon
    if reconType == 2 || reconType == 3
        img_sense = zeros(sx,sy,sz,nPhase);
        kspace_sense = zeros(sx,sy,scc,sz,nPhase);
        % perform sense recon
        for ind1 = 1:sz
            for ind2 = 1:nPhase
                [kspace_sense(:,:,:,ind1,ind2), img_sense(:,:,ind1,ind2), ~,~] = myESP_SENSE(double(kspace_sub(:,:,:,ind1,ind2)),kspace_cal(:,:,:,ind1,ind2),0);
            end
            disp(strcat(num2str(ind1),'/',num2str(sz)," completed!"));
        end
        if imgShow
            figure,imshow(abs(img_sense(:,:,1,1)),[0,0.001]); % reconstructed image
        end
        recon = img_sense;
    end
end


return