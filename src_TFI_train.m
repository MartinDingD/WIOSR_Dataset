%% 2024.06.03
%% 设置仿真参数
close all; clear; clc;
Fs = 800e3;                % 采样频率
Fc = 140e3;                % 载波频率
T = 3;             % 信号持续时间
data_len = 16000*T;           % 符号数
N = T*Fs;          %采样点数

t = 0:1/Fs:T-1/Fs;  % 时间序列
SNR = 10;                    % 信噪比
ovs = 50;       %过采样率
% JNR =   [-30, -26, -22, -18, -14, -10, -6, -2, 2, 6, 10];   % 干信比JSR范围
JNR =   [-20, -18, -16, -14, -12, -10, -8, -6, -4, -2, 0, 2, 4, 6, 8, 10];
sample_point = 4000;   %采样点个数

%% STFT参数%
% 窗口大小，推荐取 2 的幂次
wlen = 256;     % 或256
% hop size 即移动步长，一般要取一个小于 wlen 的数，推荐取 2 的幂次
hop = wlen/4;    % 或 win_len/2;
% FFT 点数，理论上应该不小于wlen，推荐取 2 的幂次
nfft = 512;     %nfft = win_len;
% 窗
win = blackman(wlen, 'periodic');


%% 余弦滚降函数生成
rolloff = 0.3;      % Rolloff factor-滚降系数，取值0-1，决定频宽和陡峭程度。取值一般大于0.2
span = 6;           % Filter span in symbols—表示截断的符号范围
sps = 50;           % Samples per symbol-单个符号范围的采样个数-和ovs对应
shape = 'sqrt';     % shape选择'sqrt'时，返回一个平方根升余弦滤波器
b = rcosdesign(rolloff, span, sps,shape);  
head = 125;      %head的设置截取N范围之外的值—对半取
% 
%% 瑞利信道
rayleighChanl = comm.RayleighChannel('SampleRate', Fs, ...
    'PathDelays', [0 1 2 ] * 1e-7, ... % 路径延迟，以秒为单位
    'AveragePathGains', [0 -4 -8 ], ... % 路径增益，以dB为单位
    'NormalizePathGains', true, ... % 归一化路径增益
    'MaximumDopplerShift', 10); % 最大多普勒频移，以Hz为单位
%'RandomStream', 'mt19937ar with seed', ... % 随机数生成器
%'Seed', 46 % 随机数种子
%% 莱斯信道
% 创建莱斯信道对象
K = 15; % 莱斯因子 (dB)
ricianChannel = comm.RicianChannel( ...
    'SampleRate', Fs, ...
    'MaximumDopplerShift', 10, ...
    'KFactor', K, ...
    'PathDelays', 0, ...
    'AveragePathGains', 0);

%% 1.添加单音干扰  将中心频率设置在[110e3,120e3]Hz之间 114
% freq = randi([200e3,220e3]); 
% cwi = cos(2*pi*freq*t);
% cwi =  sqrt(src_bpsk_p/(sum(abs(cwi).^2)/length(cwi)))*cwi;
% P_cwi = bandpower(cwi);
% ricianCwi = ricianChannel(cwi.');
% % 时域数据
% src_cwi_jnr = zeros(11,N);
% for i = 1:11
%     src_cwi_jnr(i,:)= sqrt((src_bpsk_p/P_cwi)*10^(JSR(i)/10))* ricianCwi.';
%     src_cwi_jnr(i,:) = awgn(src_cwi_jnr(i,:),SNR,'measured');
% end
freq = randi([200e3,220e3]);          % 随机载频 (Hz)
cwi  = cos(2*pi*freq*t);              % 原始单音
cwi  = rayleighChanl(cwi.').';           % 莱斯信道
cwi  = cwi / sqrt(mean(abs(cwi).^2)); % 单位功率归一化
P_cwi = bandpower(cwi);

src_cwi_jnr = zeros(11,N);
for k = 1:16
    src_cwi_jnr(k,:) = awgn(cwi, JNR(k), 'measured');   % 加噪满足 JNR
end
% 时频图像
for i = 1:16
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/cwi/snr_', num2str(i)];
    iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\cwi\snr_', num2str(i)];

    for j=1:500
        iq_segment = src_cwi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');

%         %时频图;
%         [S2, F2, T2] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T2, F2, S2);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
% %         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/cwi/snr_',num2str(i),'/',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\cwi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         close all;

        % % ===== 新增：生成星座图 =====
        % figure('visible','off');100
        % scatter(time_real, time_imag, 5, 'filled');
        % xlim([-4 4]); ylim([-4 4]);
        % axis off; set(gca,'position',[0 0 1 1]); set(gca,'Color','none');
        % % constellation_file_path = fullfile(iq_save_dir, [num2str(j), '_constellation.jpg']);
        % h = getframe(gcf); h.cdata = imresize(h.cdata,[224,224]);
        % imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\CD\cwi\snr_',num2str(i),'\',num2str(j),'.jpg']);
        % close all;
    end
end


%% 3.添加多音干扰  
num_tones = 3;
freqs = [randi([110e3 120e3]), randi([160e3 170e3]), randi([190e3 200e3])];
scwi = zeros(1,N);
for m = 1:num_tones
    scwi = scwi + cos(2*pi*freqs(m)*t);
end
scwi = rayleighChanl(scwi.').';                    % 信道
scwi = scwi / sqrt(mean(abs(scwi).^2));         % 单位功率

src_scwi_jnr = zeros(11,N);
for k = 1:16
    src_scwi_jnr(k,:) = awgn(scwi, JNR(k), 'measured');
end
% 时频图像
for i = 1:16
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/scwi/snr_', num2str(i)];
    iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\scwi\snr_', num2str(i)];
    for j=1:500
        iq_segment = src_scwi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');
        
% figure;
%         [S3, F3, T3] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T3, F3, S3);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
% %         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/scwi/snr_',num2str(i),'/',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\scwi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         close all;
    end
end



%% 5.添加宽带线性扫频干扰
f0 = 0; f1 = 16e6*T;                          % 0 Hz → 16 MHz
lfmi = chirp(t,f0,T,f1);
lfmi = rayleighChanl(lfmi.').';                  % 信道
lfmi = lfmi / sqrt(mean(abs(lfmi).^2));

src_lfmi_jnr = zeros(11,N);
for k = 1:16
    src_lfmi_jnr(k,:) = awgn(lfmi,JNR(k),'measured');
end

% 时频图像
for i = 1:16
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/lfmi/snr_', num2str(i)];
    iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\lfmi\snr_', num2str(i)];
    for j=1:500
        iq_segment = src_lfmi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');
        
% %         figure;
%         [S5, F5, T5] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T5, F5, S5);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
% %         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/lfmi/snr_',num2str(i),'/',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\lfmi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         close all;
    end
end



%% 6.添加脉冲干扰信号
D = 0:1/1500:T; pulse_w = 1e-5;
pi_sig = pulstran(t,D,'rectpuls',pulse_w);
pi_sig = rayleighChanl(pi_sig.').';           % 信道
pi_sig = pi_sig / sqrt(mean(abs(pi_sig).^2));

src_pi_jnr = zeros(11,N);
for k = 1:16
    src_pi_jnr(k,:) = awgn(pi_sig,JNR(k),'measured');
end
% 时频图像
for i = 1:16
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/pi/snr_', num2str(i)];
   iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\pi\snr_', num2str(i)];
   for j=1:500
       iq_segment = src_pi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');

% %         figure;
%         [S6, F6, T6] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T6, F6, S6);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
        % imwrite(h.cdata, ['D:\pythonproject\pytorch\Data\fourteenrayleigh\dataset\train\scwi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/pi/snr_',num2str(i),'/',num2str(j),'.jpg']);
    % %     imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\pi\snr_',num2str(i),'\',num2str(j),'.jpg']);
    % %     close all;
    end
end


%% 7.添加窄带干扰信号
fc = 250e3;  Wi = 40e3;
nbi_tmp = randn(1,N);
f = linspace(-Fs/2, Fs/2, N);
H = double(abs(f-fc)<=Wi/2 | abs(f+fc)<=Wi/2);
h_t = ifftshift(ifft(ifftshift(H)));
nbi = conv(nbi_tmp,h_t,'same');
release(rayleighChanl);
nbi = rayleighChanl(nbi.').';                 % 信道
nbi = nbi / sqrt(mean(abs(nbi).^2));

src_nbi_jnr = zeros(11,N);
for k = 1:16
    src_nbi_jnr(k,:) = awgn(nbi,JNR(k),'measured');
end
% 时频图像
for i = 1:16
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/nbi/snr_', num2str(i)];
    iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\nbi\snr_', num2str(i)];
    for j=1:500
        iq_segment = src_nbi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');

%         figure;
%         [S7, F7, T7] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T7, F7, S7);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
% %         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/nbi/snr_',num2str(i),'/',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\nbi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         close all;
    end
end

%% 4.添加梳状谱干扰
center_freqs = [50e3 200e3 300e3]; Wi = 20e3;
csi = zeros(1,N);
for fc_i = center_freqs
    H = double(abs(f-fc_i)<=Wi/2 | abs(f+fc_i)<=Wi/2);
    h_t = ifftshift(ifft(ifftshift(H)));
    csi = csi + conv(randn(1,N),h_t,'same');
end
csi = rayleighChanl(csi.').';                % 信道
csi = csi / sqrt(mean(abs(csi).^2));

src_csi_jnr = zeros(11,N);
for k = 1:16
    src_csi_jnr(k,:) = awgn(csi,JNR(k),'measured');
end
% 时频图像
for i = 1:16
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/csi/snr_', num2str(i)];
    iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\csi\snr_', num2str(i)];
    for j=1:500
        iq_segment = src_csi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');

%         figure;
%         [S4, F4, T4] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T4, F4, S4);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
% %         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/csi/snr_',num2str(i),'/',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\csi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         close all;
    end
end

%% 8.添加宽带噪声干扰
% 设置参数
Wi = (Fs/2)*2/3;
wbi = randn(1,N);
H  = double(abs(f)<=Wi);
h_t = ifftshift(ifft(ifftshift(H)));
wbi = conv(wbi,h_t,'same');
wbi = rayleighChanl(wbi.').';                % 信道
wbi = wbi / sqrt(mean(abs(wbi).^2));

src_wbi_jnr = zeros(11,N);
for k = 1:16
    src_wbi_jnr(k,:) = awgn(wbi,JNR(k),'measured');
end
% 时频图像
for i = 1:16 
%     iq_save_dir = ['/home/dell/Data/dsj/Data/osr/dataset/IQ/wbi/snr_', num2str(i)];
    iq_save_dir = ['E:\Data\osr_3path\dataset\IQ\wbi\snr_', num2str(i)];
    for j=1:500
        iq_segment = src_wbi_jnr(i, (j-1)*sample_point+1 : j*sample_point);%时域
        time_real = real(iq_segment);
        time_imag = imag(iq_segment);
        iq_freq = fft(iq_segment); %频域
        freq_real = real(iq_freq);
        freq_imag = imag(iq_freq);
        % 保存 IQ 数据为 .mat 文件
        iq_file_path = fullfile(iq_save_dir, [num2str(j), '.mat']);
        save(iq_file_path, 'time_real','time_imag','freq_real','freq_imag');

%         figure;
%         [S8, F8, T8] = stft(iq_segment, Fs, 'Window', win, 'OverlapLength',wlen - hop,'FFTLength',nfft);
%         PlotSTFT(T8, F8, S8);
%         % 删除colorbar
%         h = colorbar; delete(h);
%         % 取单边谱
%         ylim([0 400]);
%         % 使图片填充整个figure(删除白边）
%         set(gca,'position',[0 0 1 1])
%         set(gca,'xtick',[],'xticklabel',[]);
%         set(gca,'ytick',[],'yticklabel',[]);
%         set(gca, 'Color', 'none'); % Sets axes background
%         axis off;
%         h = getframe(gcf);
%         h.cdata = imresize(h.cdata,[224,224]);  % 修改图片像素尺寸中长和宽
% %         imwrite(h.cdata, ['/home/dell/Data/dsj/Data/osr/dataset/TFI/wbi/snr_',num2str(i),'/',num2str(j),'.jpg']);
%         imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\TFI\wbi\snr_',num2str(i),'\',num2str(j),'.jpg']);
%         close all;

        % figure('visible','off');
        % scatter(time_real, time_imag, 5, 'filled');
        % xlim([-4 4]); ylim([-4 4]);
        % axis off; set(gca,'position',[0 0 1 1]); set(gca,'Color','none');
        % % constellation_file_path = fullfile(iq_save_dir, [num2str(j), '_constellation.jpg']);
        % h = getframe(gcf); h.cdata = imresize(h.cdata,[224,224]);
        % imwrite(h.cdata, ['E:\datasets\osr_-2010\dataset\CD\i\snr_',num2str(i),'\',num2str(j),'.jpg']);
        % close all;
        
    end
end


