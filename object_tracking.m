%使用前需要先addpath(genpath('libs/tracking'));
%输入:uint8灰度图像last_frame,uint8灰度图像this_frame,逻辑值this_frame是否是第一帧is_first_frame,上一帧的边界last_contour,需要维持的全局变量opticalFlow
%输出:投影变换H,当前帧边界this_contour,需要维持的全局变量opticalFlow
function [H,this_contour,opticalFlow] = object_tracking(last_frame,this_frame,is_first_frame,last_contour,opticalFlow)
    if is_first_frame == true
        opticalFlow = opticalFlowLK('NoiseThreshold',0.009);
        estimateFlow(opticalFlow,this_frame);
        H = [1,0,0;0,1,0;0,0,1];
        this_contour = last_contour;
        return
    end
    
    [img_height,img_width] = size(this_frame);

    %求出上一帧到这一帧的光流
    flow = estimateFlow(opticalFlow,this_frame);
    %figure,plot(flow,'DecimationFactor',[5 5],'ScaleFactor',10)

    %估计投影变换需要至少4对corner,因此要求harris返回上一帧至少4个corner
    last_contour_list = matrix2list(last_contour,1);
    [last_contour_count,~] = size(last_contour_list);
    last_corner_list = harris(last_frame,last_contour_list,4);

    matchedpoints_last = last_corner_list;%找到的上一帧的角点位置
    
    matchedpoints_this = matchedpoints_last;%找到的角点根据光流法对应出的这一帧的位置
    [count,~] = size(matchedpoints_this);
    for i = 1:count %计算上一帧的角点按照光流法,这一帧应该到哪了
        last_y = matchedpoints_this(i,1);
        last_x = matchedpoints_this(i,2);
        dx = round(flow.Vx(last_y,last_x));
        dy = round(flow.Vy(last_y,last_x));
        
        this_y = last_y+dy;
        this_x = last_x+dx;
        if this_x > img_width
            this_x = img_width;
        end
        if this_x < 1
            this_x = 1;
        end
        if this_y > img_height
            this_y = img_height;
        end
        if this_y < 1
            this_y = 1;
        end
        matchedpoints_this(i,:) = [this_y,this_x];
    end

    tform = estimateGeometricTransform(fliplr(matchedpoints_last),fliplr(matchedpoints_this),'projective');
    H = tform.T%从角点位置变换,得到两帧之间的投影变换关系

    this_contour_list = fliplr(last_contour_list);
    for i = 1:last_contour_count
        cur_point = this_contour_list(i,:);
        extended_cur_point = [cur_point';1];
        transformed_extended_cur_point = H'*extended_cur_point;
        transformed_x = round(transformed_extended_cur_point(1) / transformed_extended_cur_point(3));
        transformed_y = round(transformed_extended_cur_point(2) / transformed_extended_cur_point(3));
        this_contour_list(i,:) = [transformed_y,transformed_x];
    end

    this_contour = list2matrix(this_contour_list,1,img_height,img_width);
    
    this_contour = imclose(this_contour,strel('disk',3));

end
