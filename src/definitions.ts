import type { PluginListenerHandle } from '@capacitor/core';

export interface CallKitVoipPlugin {
  register(): Promise<void>;

  addListener(
      eventName: 'registration',
      listenerFunc: (token:CallToken)   => void
  ): Promise<PluginListenerHandle> & PluginListenerHandle;

  addListener(
      eventName: 'callAnswered',
      listenerFunc: (callData: CallData)  => void
  ): Promise<PluginListenerHandle> & PluginListenerHandle;

  addListener(
      eventName: 'callStarted',
      listenerFunc: (callData: CallData) => void
  ): Promise<PluginListenerHandle> & PluginListenerHandle;

  addListener(
      eventName: 'callEnded',
      listenerFunc: (callData: CallData) => void
  ): Promise<PluginListenerHandle> & PluginListenerHandle;
}




export type CallType = 'video' | 'audio';

export interface CallToken {
  /**
   * VOIP Token
   */
  value: string;
}

export interface CallData {
  /**
   * Call ID
   */
  id:string;
  /**
   * Call Type
   */
  media?: CallType;
  /**
   * Call Display name
   */
  name?:string;
  /**
   * Call duration
   */
  duration?:string;
}